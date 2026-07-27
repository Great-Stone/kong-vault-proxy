#!/usr/bin/env bash
# 1) AppRole auth via Kong (secret_id one-shot 30s)
# 2) Token renewal from AppRole-issued token
# 3) Vault node failure + recovery via Kong Upstream health
# 4) X-Vault-Request, cache invalidate on write
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$DEMO_DIR/data"
INIT_JSON="$DATA_DIR/init.json"
PROXY_URL="${KONG_PROXY_URL:-http://localhost:8000}"
ADMIN_TOKEN="${KONG_ADMIN_TOKEN:-kongadmin}"
ADMIN_API="${KONG_ADMIN_API:-http://localhost:8001}"
APP_A_PATH="/secret/data/app-a/demo"
APP_B_PATH="/secret/data/app-b/demo"
INTERNAL_APP_A_PATH="/app/secret/data/app-a/demo"
INTERNAL_APP_B_PATH="/app/secret/data/app-b/demo"
APP_A_KEY="vault-app-a-key"
APP_B_KEY="vault-app-b-key"
APP_KEY="vault-app-key"
VR=( -H "X-Vault-Request: true" )

pass=0
fail=0
ok()   { pass=$((pass+1)); printf 'PASS: %s\n' "$*"; }
bad()  { fail=$((fail+1)); printf 'FAIL: %s\n' "$*" >&2; }
log()  { printf -- '--> %s\n' "$*"; }

ROOT_TOKEN="$(jq -r '.root_token' "$INIT_JSON")"
UNSEAL_KEY="$(jq -r '.unseal_keys_b64[0]' "$INIT_JSON")"

proxy_get() {
  local path="${1:-$APP_A_PATH}"
  local key="${2:-$APP_A_KEY}"
  curl -sS -D - -o /tmp/sp-body.json -H "apikey: $key" "${VR[@]}" \
    "${PROXY_URL}${path}" || true
}

# ---------- 0) X-Vault-Request required ----------
log "0) X-Vault-Request header"
code="$(curl -sS -o /dev/null -w '%{http_code}' \
  -H "apikey: $APP_A_KEY" \
  "${PROXY_URL}${APP_A_PATH}" || true)"
if [[ "$code" == "412" ]]; then
  ok "missing X-Vault-Request returns 412"
else
  bad "missing X-Vault-Request expected 412 (got HTTP $code)"
fi

# ---------- 1) AppRole auth ----------
log "1) AppRole auth through Kong"
hdr="$(proxy_get "$APP_A_PATH" "$APP_A_KEY")"
code="$(printf '%s' "$hdr" | awk 'NR==1{print $2}')"
body="$(cat /tmp/sp-body.json 2>/dev/null || true)"
if [[ "$code" == "200" ]] && printf '%s' "$body" | jq -e '.data.data.password == "app-a-secret"' >/dev/null 2>&1; then
  ok "AppRole login + app-a KV read"
else
  bad "app-a GET expected 200 with app-a-secret (got HTTP $code body=$body)"
fi

hdr="$(proxy_get "$APP_B_PATH" "$APP_A_KEY")"
code="$(printf '%s' "$hdr" | awk 'NR==1{print $2}')"
if [[ "$code" == "403" ]]; then
  ok "app-a credential is denied on app-b Route"
else
  bad "app-a credential on app-b Route expected 403 (got HTTP $code)"
fi

hdr="$(proxy_get "$APP_B_PATH" "$APP_B_KEY")"
code="$(printf '%s' "$hdr" | awk 'NR==1{print $2}')"
body="$(cat /tmp/sp-body.json 2>/dev/null || true)"
if [[ "$code" == "200" ]] && printf '%s' "$body" | jq -e '.data.data.password == "app-b-secret"' >/dev/null 2>&1; then
  ok "app-b credential reads app-b KV"
else
  bad "app-b GET expected 200 with app-b-secret (got HTTP $code body=$body)"
fi

code="$(curl -sS -o /tmp/sp-body.json -w '%{http_code}' \
  -H "apikey: $APP_KEY" "${VR[@]}" \
  "${PROXY_URL}${INTERNAL_APP_A_PATH}" || true)"
body="$(cat /tmp/sp-body.json 2>/dev/null || true)"
if [[ "$code" == "200" ]] && printf '%s' "$body" | jq -e '.data.data.password == "app-a-secret"' >/dev/null 2>&1; then
  ok "App apikey reads app-a via /app Route"
else
  bad "App /app app-a expected 200 (got HTTP $code body=$body)"
fi

code="$(curl -sS -o /tmp/sp-body.json -w '%{http_code}' \
  -H "apikey: $APP_KEY" "${VR[@]}" \
  "${PROXY_URL}${INTERNAL_APP_B_PATH}" || true)"
body="$(cat /tmp/sp-body.json 2>/dev/null || true)"
if [[ "$code" == "200" ]] && printf '%s' "$body" | jq -e '.data.data.password == "app-b-secret"' >/dev/null 2>&1; then
  ok "App apikey reads app-b via /app Route"
else
  bad "App /app app-b expected 200 (got HTTP $code body=$body)"
fi

code="$(curl -sS -o /dev/null -w '%{http_code}' \
  -H "apikey: $APP_KEY" "${VR[@]}" \
  "${PROXY_URL}${APP_A_PATH}" || true)"
if [[ "$code" == "403" ]]; then
  ok "App apikey is denied on Client Route"
else
  bad "App apikey on Client Route expected 403 (got HTTP $code)"
fi

code="$(curl -sS -o /dev/null -w '%{http_code}' \
  -H "apikey: $APP_A_KEY" "${VR[@]}" \
  "${PROXY_URL}${INTERNAL_APP_A_PATH}" || true)"
if [[ "$code" == "403" ]]; then
  ok "Client apikey is denied on App Route"
else
  bad "Client apikey on App Route expected 403 (got HTTP $code)"
fi

# secret_id is one-shot: second login with same id must fail at Vault
SECRET_ID="$(cat "$DATA_DIR/approle_secret_id" 2>/dev/null || true)"
ROLE_ID="$(cat "$DATA_DIR/approle_role_id" 2>/dev/null || true)"
if [[ -n "$SECRET_ID" && -n "$ROLE_ID" ]]; then
  reuse="$(curl -sS -o /tmp/approle-reuse.json -w '%{http_code}' \
    -H "Content-Type: application/json" \
    -d "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$SECRET_ID\"}" \
    http://127.0.0.1:18200/v1/auth/approle/login || true)"
  if [[ "$reuse" != "200" ]]; then
    ok "AppRole secret_id is single-use (Vault login reuse => HTTP $reuse)"
  else
    bad "AppRole secret_id should be single-use but reuse login succeeded"
  fi
else
  bad "missing role_id/secret_id files under demo/data"
fi

CHECK_SECRET_ID="$(docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 \
  vault write -field=secret_id -f auth/approle/role/kong-vault-proxy/secret-id)"
CHECK_LOGIN="$(curl -sS \
  -H "Content-Type: application/json" \
  -d "{\"role_id\":\"$ROLE_ID\",\"secret_id\":\"$CHECK_SECRET_ID\"}" \
  http://127.0.0.1:18200/v1/auth/approle/login)"
CHECK_TOKEN="$(printf '%s' "$CHECK_LOGIN" | jq -r '.auth.client_token // empty')"
CHECK_LOOKUP="$(curl -sS -H "X-Vault-Token: $CHECK_TOKEN" \
  http://127.0.0.1:18200/v1/auth/token/lookup-self)"
if printf '%s' "$CHECK_LOOKUP" | jq -e \
  '.data.orphan == true and .data.renewable == true and .data.period == 30' >/dev/null; then
  ok "AppRole issues renewable orphan periodic token (period=30s)"
else
  bad "AppRole token is not renewable orphan periodic: $CHECK_LOOKUP"
fi

# ---------- 1b) cache HIT + write invalidation ----------
log "1b) cache HIT and write invalidation"
tmp="$(mktemp)"
curl -sS -D "$tmp" -o /dev/null -H "apikey: $APP_A_KEY" "${VR[@]}" \
  "${PROXY_URL}${APP_A_PATH}" || true
curl -sS -D "$tmp" -o /dev/null -H "apikey: $APP_A_KEY" "${VR[@]}" \
  "${PROXY_URL}${APP_A_PATH}" || true
hit="$(tr -d '\r' < "$tmp" | awk -F': ' 'tolower($1)=="x-kong-vault-proxy-cache"{print $2; exit}')"
if [[ "$hit" == "HIT" ]]; then
  ok "second GET is cache HIT"
else
  bad "expected cache HIT (got '${hit:-missing}')"
fi

put_code="$(curl -sS -o /tmp/sp-put.json -w '%{http_code}' -X POST \
  -H "apikey: $APP_A_KEY" "${VR[@]}" -H "Content-Type: application/json" \
  -d '{"data":{"password":"app-a-rotated","env":"demo"}}' \
  "${PROXY_URL}${APP_A_PATH}" || true)"
if [[ "$put_code" == "200" ]]; then
  ok "KV write through proxy (HTTP $put_code)"
else
  bad "KV write expected 200 (got HTTP $put_code body=$(cat /tmp/sp-put.json))"
fi

curl -sS -D "$tmp" -o /tmp/sp-body.json -H "apikey: $APP_A_KEY" "${VR[@]}" \
  "${PROXY_URL}${APP_A_PATH}" || true
after="$(tr -d '\r' < "$tmp" | awk -F': ' 'tolower($1)=="x-kong-vault-proxy-cache"{print $2; exit}')"
body="$(cat /tmp/sp-body.json 2>/dev/null || true)"
if [[ "$after" == "MISS" ]] && printf '%s' "$body" | jq -e '.data.data.password == "app-a-rotated"' >/dev/null 2>&1; then
  ok "write invalidated cache (MISS + new value)"
else
  bad "after write expected MISS with app-a-rotated (cache=$after body=$body)"
fi

# restore demo secret for later tests
curl -sS -o /dev/null -X POST \
  -H "apikey: $APP_A_KEY" "${VR[@]}" -H "Content-Type: application/json" \
  -d '{"data":{"password":"app-a-secret","env":"demo"}}' \
  "${PROXY_URL}${APP_A_PATH}" || true
rm -f "$tmp"

# ---------- 2) Token renewal ----------
log "2) periodic token renewal at 4/5 of 30s (24s)"
log "waiting 31s (past original token TTL)..."
sleep 31

hdr="$(proxy_get "$APP_A_PATH" "$APP_A_KEY")"
code="$(printf '%s' "$hdr" | awk 'NR==1{print $2}')"
if [[ "$code" == "200" ]]; then
  ok "proxy returns 200 after first 4/5 renewal"
else
  bad "proxy after first renewal got HTTP $code"
fi

log "waiting another 26s (past the once-renewed token TTL)..."
sleep 26
hdr="$(proxy_get "$APP_A_PATH" "$APP_A_KEY")"
code="$(printf '%s' "$hdr" | awk 'NR==1{print $2}')"
if [[ "$code" == "200" ]]; then
  ok "proxy returns 200 after consecutive periodic renewals"
else
  bad "proxy after consecutive renewals got HTTP $code"
fi

# ---------- 3) Failure + recovery ----------
log "3) Vault failure and recovery"
leader="vault-1"
for n in vault-1 vault-2 vault-3; do
  port=18200
  [[ "$n" == vault-2 ]] && port=18202
  [[ "$n" == vault-3 ]] && port=18203
  body="$(curl -sS "http://127.0.0.1:${port}/v1/sys/leader" -H "X-Vault-Token: $ROOT_TOKEN" 2>/dev/null || true)"
  if printf '%s' "$body" | jq -e '.is_self == true' >/dev/null 2>&1; then
    leader="$n"
    break
  fi
done

log "stopping leader $leader"
docker stop "$leader" >/dev/null

sleep 8
hdr="$(proxy_get "$APP_A_PATH" "$APP_A_KEY")"
code="$(printf '%s' "$hdr" | awk 'NR==1{print $2}')"
if [[ "$code" == "200" ]]; then
  ok "proxy survives leader outage ($leader stopped)"
else
  sleep 5
  hdr="$(proxy_get "$APP_A_PATH" "$APP_A_KEY")"
  code="$(printf '%s' "$hdr" | awk 'NR==1{print $2}')"
  if [[ "$code" == "200" ]]; then
    ok "proxy survives leader outage after election ($leader)"
  else
    bad "proxy during outage got HTTP $code"
  fi
fi

log "starting + unsealing $leader"
docker start "$leader" >/dev/null
for i in $(seq 1 30); do
  port=18200
  [[ "$leader" == vault-2 ]] && port=18202
  [[ "$leader" == vault-3 ]] && port=18203
  if curl -sf "http://127.0.0.1:${port}/v1/sys/health?standbyok=true&perfstandbyok=true&sealedcode=200&uninitcode=200" >/dev/null; then
    break
  fi
  sleep 1
done
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 "$leader" vault operator unseal "$UNSEAL_KEY" >/dev/null || true
sleep 5

hdr="$(proxy_get "$APP_A_PATH" "$APP_A_KEY")"
code="$(printf '%s' "$hdr" | awk 'NR==1{print $2}')"
if [[ "$code" == "200" ]]; then
  ok "proxy healthy after $leader recovery"
else
  bad "proxy after recovery got HTTP $code"
fi

printf '\nRESULT: %d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
