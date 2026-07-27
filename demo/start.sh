#!/usr/bin/env bash
# Bring up Vault HA (3 nodes), init/unseal, AppRole, wire kong-vault-proxy, verify.
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$DEMO_DIR/.." && pwd)"
ENTERPRISE_DOCKER="${KONG_ENTERPRISE_DOCKER:-$PLUGIN_ROOT/../../../kong-enterprise/docker}"
ENTERPRISE_DOCKER="$(cd "$ENTERPRISE_DOCKER" && pwd)"
DATA_DIR="$DEMO_DIR/data"
INIT_JSON="$DATA_DIR/init.json"
SECRET_ID_FILE="$DATA_DIR/approle_secret_id"
ROLE_ID_FILE="$DATA_DIR/approle_role_id"
OVERRIDE_YML="$DATA_DIR/kong-override.gen.yml"
WORKSPACE="${KONG_VAULT_PROXY_WORKSPACE:-kong-vault-proxy}"

ADMIN_TOKEN="${KONG_ADMIN_TOKEN:-kongadmin}"
ADMIN_API="${KONG_ADMIN_API:-http://localhost:8001}"
PROXY_URL="${KONG_PROXY_URL:-http://localhost:8000}"

log() { printf -- '==> %s\n' "$*"; }
fail() { printf -- 'FAIL: %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null || fail "missing command: $1"; }
need docker
need deck
need curl
need jq

[[ -d "$ENTERPRISE_DOCKER" ]] || fail "Kong Enterprise docker not found: $ENTERPRISE_DOCKER"
docker network inspect kong-net >/dev/null || fail "docker network kong-net missing (start kong-enterprise first)"
curl -sf -H "Kong-Admin-Token: $ADMIN_TOKEN" "$ADMIN_API/" >/dev/null \
  || fail "Kong Admin API not reachable at $ADMIN_API"

mkdir -p "$DATA_DIR"/vault-{1,2,3}
chmod 777 "$DATA_DIR"/vault-{1,2,3} 2>/dev/null || true
: > "$SECRET_ID_FILE"
chmod 644 "$SECRET_ID_FILE"

# --- Vault HA ---
log "starting Vault 3-node cluster"
docker compose -f "$DEMO_DIR/docker-compose.yml" up -d

wait_vault_http() {
  local addr="$1"
  for _ in $(seq 1 60); do
    if curl -sf "$addr/v1/sys/health?standbyok=true&uninitcode=200&sealedcode=200" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_vault_http http://127.0.0.1:18200 || fail "vault-1 not responding"
wait_vault_http http://127.0.0.1:18202 || fail "vault-2 not responding"
wait_vault_http http://127.0.0.1:18203 || fail "vault-3 not responding"

v1() { docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault-1 vault "$@"; }
v2() { docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault-2 vault "$@"; }
v3() { docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault-3 vault "$@"; }

if [[ ! -f "$INIT_JSON" ]]; then
  log "initializing vault-1"
  v1 operator init -key-shares=1 -key-threshold=1 -format=json > "$INIT_JSON"
fi

UNSEAL_KEY="$(jq -r '.unseal_keys_b64[0]' "$INIT_JSON")"
ROOT_TOKEN="$(jq -r '.root_token' "$INIT_JSON")"
[[ -n "$UNSEAL_KEY" && "$UNSEAL_KEY" != null ]] || fail "unseal key missing in $INIT_JSON"
[[ -n "$ROOT_TOKEN" && "$ROOT_TOKEN" != null ]] || fail "root token missing in $INIT_JSON"

log "unsealing vault-1"
v1 operator unseal "$UNSEAL_KEY" >/dev/null || true

log "joining + unsealing vault-2/3"
v2 operator raft join http://vault-1:8200 >/dev/null || true
v2 operator unseal "$UNSEAL_KEY" >/dev/null || true
v3 operator raft join http://vault-1:8200 >/dev/null || true
v3 operator unseal "$UNSEAL_KEY" >/dev/null || true

s1=000; s2=000; s3=000
for _ in $(seq 1 60); do
  s1="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:18200/v1/sys/health?standbyok=true&perfstandbyok=true' || true)"
  s2="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:18202/v1/sys/health?standbyok=true&perfstandbyok=true' || true)"
  s3="$(curl -s -o /dev/null -w '%{http_code}' 'http://127.0.0.1:18203/v1/sys/health?standbyok=true&perfstandbyok=true' || true)"
  if [[ "$s1" == "200" && "$s2" == "200" && "$s3" == "200" ]]; then
    break
  fi
  v2 operator raft join http://vault-1:8200 >/dev/null 2>&1 || true
  v3 operator raft join http://vault-1:8200 >/dev/null 2>&1 || true
  v2 operator unseal "$UNSEAL_KEY" >/dev/null 2>&1 || true
  v3 operator unseal "$UNSEAL_KEY" >/dev/null 2>&1 || true
  sleep 1
done
[[ "$s1" == "200" && "$s2" == "200" && "$s3" == "200" ]] || fail "vault nodes not healthy ($s1/$s2/$s3)"

log "raft peers"
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault operator raft list-peers

log "configuring Vault admin userpass (admin/password)"
docker exec -i -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault policy write admin - <<'EOF' >/dev/null
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault auth enable userpass >/dev/null 2>&1 || true
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault write auth/userpass/users/admin password=password policies=admin >/dev/null

log "configuring KV + AppRole (one-shot secret_id, orphan periodic token=30s)"
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault secrets enable -path=secret kv-v2 >/dev/null 2>&1 || true
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault kv put secret/app-a/demo password=app-a-secret env=demo >/dev/null
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault kv put secret/app-b/demo password=app-b-secret env=demo >/dev/null

docker exec -i -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault policy write kong-vault-proxy - <<'EOF' >/dev/null
path "secret/data/app-a/*" {
  capabilities = ["create", "read", "update"]
}
path "secret/data/app-b/*" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
EOF

docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault auth enable approle >/dev/null 2>&1 || true
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault auth tune -user-lockout-disable=true approle/ >/dev/null

docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault write auth/approle/role/kong-vault-proxy \
    token_type=service \
    token_ttl=0 \
    token_max_ttl=0 \
    token_period=30s \
    token_explicit_max_ttl=0 \
    token_policies=kong-vault-proxy \
    secret_id_ttl=30s \
    secret_id_num_uses=1 >/dev/null

ROLE_ID="$(docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault read -field=role_id auth/approle/role/kong-vault-proxy/role-id)"
printf '%s' "$ROLE_ID" > "$ROLE_ID_FILE"

# Clear plugin instances in default + workspace before DP restart
clear_plugins() {
  local ws_path="${1:-}"
  local base="$ADMIN_API${ws_path}"
  for plugin_name in secret-proxy kong-vault-proxy; do
    for plugin_id in $(curl -sf -H "Kong-Admin-Token: $ADMIN_TOKEN" \
      "$base/plugins?name=$plugin_name" | jq -r '.data[].id // empty'); do
      curl -sf -X DELETE -H "Kong-Admin-Token: $ADMIN_TOKEN" \
        "$base/plugins/$plugin_id" >/dev/null || true
    done
  done
}
clear_plugins ""
clear_plugins "/$WORKSPACE"

log "ensuring Kong workspace: $WORKSPACE"
ws_code="$(curl -sS -o /tmp/kvp-ws.json -w '%{http_code}' -H "Kong-Admin-Token: $ADMIN_TOKEN" \
  "$ADMIN_API/workspaces/$WORKSPACE" || true)"
if [[ "$ws_code" == "404" ]]; then
  curl -sf -X POST -H "Kong-Admin-Token: $ADMIN_TOKEN" -H "Content-Type: application/json" \
    -d "{\"name\":\"$WORKSPACE\"}" "$ADMIN_API/workspaces" >/dev/null \
    || fail "failed to create workspace $WORKSPACE"
fi

log "applying Kong override (kong-vault-proxy plugin + shared dicts)"
# Keep ai-vision-guard enabled/mounted — DP rejects CP sync if a plugin in DB is missing from KONG_PLUGINS.
VISION_GUARD_PATH="${KONG_AI_VISION_GUARD_PATH:-$PLUGIN_ROOT/../kong-ai-vision-guard/kong/plugins/ai-vision-guard}"
VISION_GUARD_PATH="$(cd "$(dirname "$VISION_GUARD_PATH")" && pwd)/$(basename "$VISION_GUARD_PATH")"
[[ -f "$VISION_GUARD_PATH/handler.lua" ]] || fail "ai-vision-guard not found at $VISION_GUARD_PATH"

cat > "$OVERRIDE_YML" <<EOF
services:
  kong-cp:
    volumes:
      - ${VISION_GUARD_PATH}:/usr/local/share/lua/5.1/kong/plugins/ai-vision-guard:ro
      - ${PLUGIN_ROOT}/kong/plugins/kong-vault-proxy:/usr/local/share/lua/5.1/kong/plugins/kong-vault-proxy:ro
    environment:
      KONG_PLUGINS: bundled,ai-vision-guard,kong-vault-proxy
  kong-dp:
    volumes:
      - ${VISION_GUARD_PATH}:/usr/local/share/lua/5.1/kong/plugins/ai-vision-guard:ro
      - ${PLUGIN_ROOT}/kong/plugins/kong-vault-proxy:/usr/local/share/lua/5.1/kong/plugins/kong-vault-proxy:ro
      - ${DATA_DIR}:/run/kong-vault-proxy:ro
    environment:
      KONG_PLUGINS: bundled,ai-vision-guard,kong-vault-proxy
      KONG_NGINX_HTTP_LUA_SHARED_DICT: kong_vault_proxy_tokens 16m; lua_shared_dict kong_vault_proxy_cache 33m
EOF

docker compose -f "$ENTERPRISE_DOCKER/docker-compose.yml" -f "$OVERRIDE_YML" \
  up -d --force-recreate --no-deps kong-cp kong-dp

log "waiting for Kong after recreate"
for _ in $(seq 1 90); do
  if curl -sf -H "Kong-Admin-Token: $ADMIN_TOKEN" "$ADMIN_API/" >/dev/null \
     && curl -skf https://localhost:8101/status >/dev/null; then
    break
  fi
  sleep 2
done
curl -sf -H "Kong-Admin-Token: $ADMIN_TOKEN" "$ADMIN_API/" >/dev/null || fail "Kong CP not ready"
curl -skf https://localhost:8101/status >/dev/null || fail "Kong DP not ready"

log "waiting for DP config sync"
for _ in $(seq 1 60); do
  hash="$(curl -sk https://localhost:8101/status | jq -r '.configuration_hash // empty')"
  if [[ -n "$hash" && "$hash" != "00000000000000000000000000000000" ]]; then
    log "DP configuration_hash=$hash"
    break
  fi
  sleep 2
done
hash="$(curl -sk https://localhost:8101/status | jq -r '.configuration_hash // empty')"
[[ -n "$hash" && "$hash" != "00000000000000000000000000000000" ]] \
  || fail "DP has empty configuration_hash (check KONG_PLUGINS includes all CP plugins)"

curl -sf -H "Kong-Admin-Token: $ADMIN_TOKEN" "$ADMIN_API/plugins/enabled" \
  | jq -e '.enabled_plugins | index("kong-vault-proxy")' >/dev/null \
  || fail "kong-vault-proxy not in enabled plugins"

log "issuing one-shot AppRole secret_id (ttl=30s)"
SECRET_ID="$(docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault write -field=secret_id -f auth/approle/role/kong-vault-proxy/secret-id)"
printf '%s' "$SECRET_ID" > "$SECRET_ID_FILE"

log "syncing decK into workspace $WORKSPACE"
export DECK_VAULT_ROLE_ID="$ROLE_ID"
deck gateway sync "$DEMO_DIR/deck.yaml" --select-tag plugin-demo \
  --workspace "$WORKSPACE" \
  --kong-addr "$ADMIN_API" \
  --headers "Kong-Admin-Token: $ADMIN_TOKEN"

# First request forces ensure()/login within secret_id TTL
for _ in $(seq 1 15); do
  code="$(curl -sS -o /tmp/sp-warm.json -w '%{http_code}' \
    -H 'apikey: vault-app-a-key' \
    -H 'X-Vault-Request: true' \
    "${PROXY_URL}/secret/data/app-a/demo" || true)"
  if [[ "$code" == "200" ]]; then
    break
  fi
  sleep 1
done
[[ "$code" == "200" ]] || fail "warm-up app-a GET failed (HTTP $code): $(cat /tmp/sp-warm.json 2>/dev/null || true)"

log "ready"
cat <<EOF

kong-vault-proxy demo is up (workspace: ${WORKSPACE})

  Kong CP
    Admin API:     ${ADMIN_API}
    Admin token:   Kong-Admin-Token: ${ADMIN_TOKEN}
    Kong Manager:  http://localhost:8002  (OIDC: kong-admin / kongadmin)

  Kong DP
    Proxy:         ${PROXY_URL}
    Status:        https://localhost:8101/status
    Sample GET:    curl -sS -H 'apikey: vault-app-a-key' -H 'X-Vault-Request: true' \\
                     ${PROXY_URL}/secret/data/app-a/demo

  Vault
    UI:            http://127.0.0.1:18200/ui/
    Login:         userpass  admin / password
    Nodes:         18200 (vault-1), 18202 (vault-2), 18203 (vault-3)

  Verify
    ${DEMO_DIR}/test.sh

  UI
    ${DEMO_DIR}/ui/serve.sh   → http://127.0.0.1:3090

  Stop
    ${DEMO_DIR}/stop.sh

EOF
