#!/usr/bin/env bash
# Re-issue AppRole secret_id and warm Kong kong-vault-proxy (fixes UI 502 after one-shot consume / TTL).
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$DEMO_DIR/data"
INIT_JSON="$DATA_DIR/init.json"
SECRET_ID_FILE="$DATA_DIR/approle_secret_id"
ROLE_ID_FILE="$DATA_DIR/approle_role_id"

PROXY_URL="${KONG_PROXY_URL:-http://localhost:8000}"

need() { command -v "$1" >/dev/null || { echo "missing $1" >&2; exit 1; }; }
need docker
need curl
need jq

[[ -f "$INIT_JSON" ]] || { echo "missing $INIT_JSON — run ./start.sh first" >&2; exit 1; }
[[ -f "$ROLE_ID_FILE" ]] || { echo "missing role_id — run ./start.sh first" >&2; exit 1; }

ROOT_TOKEN="$(jq -r .root_token "$INIT_JSON")"
vexec() {
  docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$ROOT_TOKEN" vault-1 "$@"
}

# Match up.sh: one-shot Secret ID issues an orphan periodic service token.
vexec vault write auth/approle/role/kong-vault-proxy \
  token_policies=kong-vault-proxy \
  token_type=service \
  token_ttl=0 \
  token_max_ttl=0 \
  token_period=30s \
  token_explicit_max_ttl=0 \
  secret_id_ttl=5m \
  secret_id_num_uses=1 >/dev/null

SECRET_ID="$(vexec vault write -field=secret_id -f auth/approle/role/kong-vault-proxy/secret-id)"
printf '%s' "$SECRET_ID" > "$SECRET_ID_FILE"

# UI: IP → vault-N (Kong upstream_addr is IP)
UI_MAP="$DEMO_DIR/ui/vault-map.json"
python3 - <<PY
import json, subprocess
m = {}
for n in ("vault-1", "vault-2", "vault-3"):
    ip = subprocess.check_output([
        "docker", "inspect", "-f",
        "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}", n
    ], text=True).strip()
    if ip:
        m[ip] = n
        m[f"{ip}:8200"] = n
open("$UI_MAP", "w").write(json.dumps(m, indent=2) + "\n")
print("wrote $UI_MAP", m)
PY

code=000
for _ in $(seq 1 20); do
  code="$(curl -sS -o /tmp/sp-reauth.json -w '%{http_code}' \
    -H 'apikey: vault-app-a-key' \
    -H 'X-Vault-Request: true' \
    "${PROXY_URL}/secret/data/app-a/demo" || true)"
  [[ "$code" == "200" ]] && break
  sleep 1
done

if [[ "$code" != "200" ]]; then
  echo "reauth warm failed HTTP $code: $(cat /tmp/sp-reauth.json 2>/dev/null || true)" >&2
  exit 1
fi

echo "reauth ok (HTTP $code) — kong-vault-proxy token ready"
