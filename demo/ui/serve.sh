#!/usr/bin/env bash
# Serve the flow UI on http://127.0.0.1:3090
set -euo pipefail
UI_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${UI_PORT:-3090}"
REAUTH="${UI_DIR}/../reauth.sh"

if [[ "${SKIP_REAUTH:-0}" != "1" && -x "$REAUTH" ]]; then
  echo "warming kong-vault-proxy (AppRole)…"
  "$REAUTH" || echo "warn: reauth failed — run ./demo/reauth.sh" >&2
fi

cd "$UI_DIR"
echo "kong-vault-proxy UI → http://127.0.0.1:${PORT}"
echo "Proxy default: http://localhost:8000 (UI에서 변경 가능)"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
