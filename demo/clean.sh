#!/usr/bin/env bash
# Tear down Vault HA demo and remove this demo's Kong entities / local data.
# Does not touch kong-enterprise/docker (managed separately).
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$DEMO_DIR/data"

ADMIN_TOKEN="${KONG_ADMIN_TOKEN:-kongadmin}"
ADMIN_API="${KONG_ADMIN_API:-http://localhost:8001}"

delete_entity() {
  local endpoint="$1"
  local name="$2"
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE \
    -H "Kong-Admin-Token: $ADMIN_TOKEN" \
    "$ADMIN_API/$endpoint/$name" || true)"
  [[ "$code" == "204" || "$code" == "404" ]] \
    || { echo "failed to delete $endpoint/$name (HTTP $code)" >&2; exit 1; }
}

if [[ -f "$DATA_DIR/ui.pid" ]]; then
  ui_pid="$(cat "$DATA_DIR/ui.pid")"
  kill "$ui_pid" 2>/dev/null || true
fi

if curl -sf -H "Kong-Admin-Token: $ADMIN_TOKEN" "$ADMIN_API/" >/dev/null; then
  delete_entity routes kong-vault-proxy-internal-app
  delete_entity routes kong-vault-proxy-app-a
  delete_entity routes kong-vault-proxy-app-b
  delete_entity services kong-vault-proxy-vault
  delete_entity consumers vault-app
  delete_entity consumers vault-app-a
  delete_entity consumers vault-app-b
  delete_entity upstreams vault-cluster
fi

docker compose -f "$DEMO_DIR/docker-compose.yml" down -v
rm -rf "$DATA_DIR"
rm -f "$DEMO_DIR/ui/vault-map.json"

echo "kong-vault-proxy demo cleaned"
