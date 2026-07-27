#!/usr/bin/env bash
# Minimal check: two identical GETs → second must be X-Kong-Vault-Proxy-Cache: HIT
set -euo pipefail

PROXY_URL="${PROXY_URL:-http://localhost:8000}"
SECRET_PATH="${SECRET_PATH:-/secret/data/app-a/demo}"
API_KEY="${API_KEY:-vault-app-a-key}"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

hdr=( -H "apikey: ${API_KEY}" -H "X-Vault-Request: true" )

curl -sS -D "$tmp" -o /dev/null "${hdr[@]}" "${PROXY_URL}${SECRET_PATH}" || true
miss="$(tr -d '\r' < "$tmp" | awk -F': ' 'tolower($1)=="x-kong-vault-proxy-cache"{print $2; exit}')"

curl -sS -D "$tmp" -o /dev/null "${hdr[@]}" "${PROXY_URL}${SECRET_PATH}" || true
hit="$(tr -d '\r' < "$tmp" | awk -F': ' 'tolower($1)=="x-kong-vault-proxy-cache"{print $2; exit}')"

if [[ "${hit}" != "HIT" ]]; then
  echo "FAIL: expected X-Kong-Vault-Proxy-Cache: HIT on second request (got '${hit:-<missing>}', first='${miss:-<missing>}')" >&2
  echo "hint: plugin installed? shared dict set? Vault reachable? PROXY_URL=${PROXY_URL} SECRET_PATH=${SECRET_PATH}" >&2
  exit 1
fi

echo "OK: cache MISS then HIT on ${PROXY_URL}${SECRET_PATH}"
