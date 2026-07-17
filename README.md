# kong-vault-proxy

Proxies the HashiCorp Vault API through Kong Gateway. It provides Vault Proxy-style auto-auth, token renewal, and TTL caching, while Kong Upstream and Targets handle load balancing, health checks, and failover.

AppRole service tokens are renewable orphan periodic tokens. The plugin renews each lease at its 4/5 point.

## Benefits

- **One Vault entry point** — applications use Kong instead of managing Vault nodes, addresses, or failover logic.
- **HA without a separate load balancer** — Kong Upstream health checks, Targets, and round-robin routing provide load balancing and failover.
- **Vault authentication delegation** — Kong performs AppRole/Kubernetes authentication, token injection, and periodic renewal; applications do not handle Vault tokens.
- **Centralized access control** — Kong `key-auth`, Consumers, Routes, and ACLs restrict each application to approved Vault paths.
- **Observability** — OpenTelemetry and logging plugins can trace and log Vault requests through the standard Kong telemetry pipeline.
- **Reduced Vault load** — TTL-aware response caching serves repeated KV reads without contacting Vault.
- **Topology isolation** — clients do not need to know Vault cluster membership or the active node.
- **Consistent governance** — rate limiting, audit logging, network policy, and other Kong plugins can be applied at one boundary.

## Install

```bash
luarocks make kong-vault-proxy-0.1.0-1.rockspec
export KONG_PLUGINS="bundled,kong-vault-proxy"
export KONG_NGINX_HTTP_LUA_SHARED_DICT="kong_vault_proxy_cache 33m"
```

## Local demo

```bash
./demo/up.sh
./demo/ui/serve.sh   # http://127.0.0.1:3090
```

![UI](demo/kong-vault-proxy-demo-ui.png)

The UI supports English/Korean switching, manual Play, and automatic requests.

- Manual Client: `key-auth` + ACL on `/secret/data/...`
- Auto App: `vault-app-key` on `/app/...` only; the plugin authenticates to Vault
- Vault UI: `http://127.0.0.1:18200/ui/`
- Admin: `admin` / `password` (`admin` policy)
- Trace: `http://localhost:16686`
- Log: `http://localhost:3000/d/kong-logs-compare/kong-logs-compare`

## Verify

```bash
export PROXY_URL="${PROXY_URL:-http://localhost:8000}"
./scripts/verify.sh
```

## Configuration

| Field | Description |
|---|---|
| `token_mode` | `force` / `auto` / `passthrough` |
| `auth_method` | `token` / `approle` / `kubernetes` |
| `vault_addrs` | Login and renewal addresses |
| `cache.kv_min_cache_ttl` | Minimum KV cache TTL in seconds |
| `cache.default_ttl` | Default cache TTL in seconds |
| `cache.neg_ttl` | Error-response cache TTL in seconds |

[한국어](README_KO.md)
