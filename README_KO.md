# kong-vault-proxy

HashiCorp Vault API를 Kong에서 프록시합니다. Vault Proxy처럼 auto-auth·토큰 갱신·TTL 응답 캐시(`memory` 또는 `redis`)를 제공하며, 클러스터 LB·헬스체크(standby / performance standby 포함)·failover는 Kong Upstream + Targets가 담당합니다.

AppRole은 갱신 가능한 orphan periodic service token을 발급하며, 플러그인은 lease의 4/5 시점마다 갱신합니다. 동적(leased) secret 응답은 수신한 `lease_duration` 동안만 캐시되며 `default_ttl` / `kv_min_cache_ttl`로 연장되지 않습니다.

## 기능

- **Vault 접근 일원화** — 애플리케이션은 Vault 노드·failover 대신 Kong을 사용합니다.
- **Kong Upstream HA** — `/v1/sys/health`와 healthy 코드 `200`/`429`/`472`/`473`으로 active·standby·performance standby를 읽기 대상에 포함합니다 (Kong `http_path`는 쿼리스트링 불가).
- **Auto-auth** — `token` / `approle` / `kubernetes`, `token_mode` `force` / `auto` / `passthrough`.
- **응답 캐시** — `cache.strategy` `memory`(shm) 또는 `redis`, write 시 path 무효화, Vault Proxy식 cache-clear API, `X-Kong-Vault-Proxy-Bypass-Cache: true`로 바이패스.
- **접근 제어** — Kong `key-auth`, Consumer, Route, ACL과 함께 사용.
- **관측** — `X-Kong-Vault-Proxy-Cache` / `X-Kong-Vault-Proxy-Vault` 헤더, prometheus 플러그인 사용 시 카운터.
- **SSRF 완화** — `require_vault_request_header` (`X-Vault-Request: true` 필요).

## 설치

```bash
luarocks make kong-vault-proxy-0.2.0-1.rockspec
export KONG_PLUGINS="bundled,kong-vault-proxy"
export KONG_NGINX_HTTP_LUA_SHARED_DICT="kong_vault_proxy_tokens 16m; lua_shared_dict kong_vault_proxy_cache 33m"
```

## 로컬 데모

`kong-enterprise/docker` 스택(`kong-net`, Admin, Proxy)이 필요합니다.

```bash
./demo/start.sh
./demo/ui/serve.sh   # http://127.0.0.1:3090
./demo/stop.sh
```

- 수동 Client: `/secret/data/...`에서 `key-auth` + ACL (`X-Vault-Request: true` 필요)
- 자동 App: `vault-app-key`로 `/app/...`만 접근, 플러그인이 Vault 인증
- Workspace: `kong-vault-proxy`
- Vault UI: `http://127.0.0.1:18200/ui/` (`admin` / `password`)

```bash
export PROXY_URL="${PROXY_URL:-http://localhost:8000}"
./scripts/verify.sh
```

## 설정

| 필드 | 설명 |
|---|---|
| `token_mode` | `force` / `auto` / `passthrough` |
| `auth_method` | `token` / `approle` / `kubernetes` |
| `vault_addrs` | login·renew·health probe 주소 |
| `require_vault_request_header` | `X-Vault-Request: true` 필수 (없으면 412) |
| `enable_cache_clear` | cache-clear 경로 활성화 |
| `cache_clear_path` | 기본 `/kong-vault-proxy/v1/cache-clear` |
| `cache.enabled` | 응답 캐시 on/off (기본 `true`) |
| `cache.strategy` | `memory` 또는 `redis` |
| `cache.memory.dictionary_name` | shm 이름 (기본 `kong_vault_proxy_cache`) |
| `cache.redis.host` / `port` / `password` / `database` / `timeout` / `key_prefix` | Redis 백엔드 |
| `cache.kv_min_cache_ttl` | lease 없는(KV) 응답 최소 TTL |
| `cache.default_ttl` | lease 없는 응답 기본 TTL |
| `cache.neg_ttl` | 오류 응답 캐시 TTL |

### Redis 예시

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

`type`: `all` | `request_path` | `token` (현재 token은 전체 삭제).

[English](README.md) · [CHANGELOG](CHANGELOG.md)
