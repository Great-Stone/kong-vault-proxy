#!/usr/bin/env bash
# Tear down Vault HA demo and remove Kong workspace entities / local data.
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$DEMO_DIR/data"
WORKSPACE="${KONG_VAULT_PROXY_WORKSPACE:-kong-vault-proxy}"

ADMIN_TOKEN="${KONG_ADMIN_TOKEN:-kongadmin}"
ADMIN_API="${KONG_ADMIN_API:-http://localhost:8001}"

log() { printf -- '==> %s\n' "$*"; }

if [[ -f "$DATA_DIR/ui.pid" ]]; then
  ui_pid="$(cat "$DATA_DIR/ui.pid")"
  kill "$ui_pid" 2>/dev/null || true
fi

if curl -sf -H "Kong-Admin-Token: $ADMIN_TOKEN" "$ADMIN_API/" >/dev/null; then
  EMPTY="$(mktemp)"
  cat > "$EMPTY" <<'EOF'
_format_version: "3.0"
EOF
  log "removing Kong entities in workspace $WORKSPACE (tag plugin-demo)"
  deck gateway sync "$EMPTY" --select-tag plugin-demo \
    --workspace "$WORKSPACE" \
    --kong-addr "$ADMIN_API" \
    --headers "Kong-Admin-Token: $ADMIN_TOKEN" || true
  rm -f "$EMPTY"

  # Optional: delete workspace if empty-ish
  curl -sS -X DELETE -H "Kong-Admin-Token: $ADMIN_TOKEN" \
    "$ADMIN_API/workspaces/$WORKSPACE" >/dev/null 2>&1 || true
fi

docker compose -f "$DEMO_DIR/docker-compose.yml" down -v
rm -rf "$DATA_DIR"
rm -f "$DEMO_DIR/ui/vault-map.json"

echo "kong-vault-proxy demo cleaned"
