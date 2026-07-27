# Demo (local e2e)

Validates `kong-vault-proxy` AppRole authentication, token renewal, cache invalidation, and failover with a three-node Vault Raft cluster and Kong Enterprise (`kong-net`).

## Prerequisites

- Running `kong-enterprise/docker` (`kong-net`, Admin `:8001`, Proxy `:8000`)
- `deck`, `jq`, `docker`

## Run

```bash
./start.sh
```

Initializes and unseals Vault, configures AppRole, mounts the plugin (shm dicts for tokens and cache), syncs decK into workspace `kong-vault-proxy`, and warms AppRole login.

Then run checks when ready:

```bash
./test.sh
```

## Flow UI

```bash
./ui/serve.sh
# http://127.0.0.1:3090
```

Provides app-a, app-b, cross-ACL denial, cache MISS→HIT, cache bypass, and Auto App scenarios. Requests send `X-Vault-Request: true`.

## Checks

1. Client/App isolation using `key-auth`, Routes, and ACLs
2. Missing `X-Vault-Request` → 412
3. Cache HIT and KV write invalidation
4. AppRole Secret ID reuse rejection
5. Consecutive periodic token renewals at the 4/5 point
6. Proxy availability during Vault leader failure and recovery

## Clean up

```bash
./stop.sh
```

[한국어](README_KO.md)
