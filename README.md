# kong-vault-proxy

Proxies the HashiCorp Vault API through Kong Gateway. It provides Vault Proxy-style auto-auth, token renewal, and TTL response caching (`memory` or `redis`). Kong Upstream and Targets handle load balancing, health checks (including Vault standby / performance standby), and failover.

AppRole service tokens are renewable orphan periodic tokens. The plugin renews each lease at its 4/5 point. Dynamic (leased) secret responses are cached only for the returned `lease_duration` (not extended by `default_ttl` / `kv_min_cache_ttl`).

## Features

- **Vault entry point** — applications call Kong instead of managing Vault nodes or failover.
- **HA via Kong Upstream** — health checks use `/v1/sys/health` and treat `200`/`429`/`472`/`473` as healthy so active, standby, and performance standby stay eligible for reads (Kong `http_path` cannot carry query strings).
- **Auto-auth** — `token` / `approle` / `kubernetes`, with `token_mode` `force` / `auto` / `passthrough`.
- **Response cache** — `cache.strategy` `memory` (shm) or `redis`; path invalidation on writes; Vault Proxy-style cache-clear API; bypass with `X-Kong-Vault-Proxy-Bypass-Cache: true`.
- **Access control** — combine with Kong `key-auth`, Consumers, Routes, and ACL.
- **Observability** — response headers `X-Kong-Vault-Proxy-Cache` / `X-Kong-Vault-Proxy-Vault`; Prometheus counters when the prometheus plugin is enabled.
- **SSRF guard** — optional `require_vault_request_header` (expects `X-Vault-Request: true`).

## Install

```bash
luarocks make kong-vault-proxy-0.2.0-1.rockspec
export KONG_PLUGINS="bundled,kong-vault-proxy"
export KONG_NGINX_HTTP_LUA_SHARED_DICT="kong_vault_proxy_tokens 16m; lua_shared_dict kong_vault_proxy_cache 33m"
```

## Local demo

Requires a running `kong-enterprise/docker` stack (`kong-net`, Admin, Proxy).

```bash
./demo/start.sh
./demo/ui/serve.sh   # http://127.0.0.1:3090
./demo/stop.sh
```

- Manual Client: `key-auth` + ACL on `/secret/data/...` (send `X-Vault-Request: true`)
- Auto App: `vault-app-key` on `/app/...` only; the plugin authenticates to Vault
- Workspace: `kong-vault-proxy`
- Vault UI: `http://127.0.0.1:18200/ui/` (`admin` / `password`)

```bash
export PROXY_URL="${PROXY_URL:-http://localhost:8000}"
./scripts/verify.sh
```

## Configuration

| Field | Description |
|---|---|
| `token_mode` | `force` / `auto` / `passthrough` |
| `auth_method` | `token` / `approle` / `kubernetes` |
| `vault_addrs` | Login, renew, and health-probe addresses |
| `require_vault_request_header` | Require `X-Vault-Request: true` (412 if missing) |
| `enable_cache_clear` | Enable `POST` cache-clear path |
| `cache_clear_path` | Default `/kong-vault-proxy/v1/cache-clear` |
| `cache.enabled` | Enable response caching (default `true`) |
| `cache.strategy` | `memory` or `redis` |
| `cache.memory.dictionary_name` | shm name (default `kong_vault_proxy_cache`) |
| `cache.redis.host` / `port` / `password` / `database` / `timeout` / `key_prefix` | Redis backend |
| `cache.kv_min_cache_ttl` | Minimum TTL for non-leased (KV) responses |
| `cache.default_ttl` | Default TTL for non-leased responses |
| `cache.neg_ttl` | Error-response cache TTL |

### Redis example

```yaml
cache:
  enabled: true
  strategy: redis
  redis:
    host: redis
    port: 6379
    password: redispass
    key_prefix: "kong_vault_proxy:"
```

### Cache-clear

```bash
curl -X POST "$PROXY_URL/kong-vault-proxy/v1/cache-clear" \
  -H "apikey: vault-app-a-key" \
  -H "X-Vault-Request: true" \
  -H "Content-Type: application/json" \
  -d '{"type":"all"}'
```

`type`: `all` | `request_path` | `token` (token clears all in this release).

[한국어](README_KO.md) · [CHANGELOG](CHANGELOG.md)
