# kong-vault-proxy

HashiCorp Vault API를 Kong에서 프록시합니다. Vault Proxy처럼 auto-auth·토큰 갱신·TTL 캐시를 제공하며, 클러스터 LB·헬스체크·failover는 Kong Upstream + Targets가 담당합니다.

AppRole은 갱신 가능한 orphan periodic service token을 발급하며, 플러그인은 lease의 4/5 시점마다 갱신합니다.

## 장점

- **Vault 접근 일원화** — 애플리케이션은 Vault 노드·주소·failover 로직 대신 Kong 단일 진입점을 사용합니다.
- **별도 Load Balancer 없는 HA** — Kong Upstream의 헬스체크·Targets·Round Robin이 부하 분산과 failover를 담당합니다.
- **Vault 인증 대행** — Kong이 AppRole/Kubernetes 인증, Vault 토큰 주입과 periodic 갱신을 처리하므로 애플리케이션이 Vault 토큰을 관리하지 않습니다.
- **중앙 집중식 접근제어** — Kong `key-auth`, Consumer, Route와 ACL로 애플리케이션별 Vault 경로를 제한합니다.
- **요청 가시성** — OpenTelemetry와 Logging Plugin을 통해 Vault 요청을 기존 Kong 텔레메트리 파이프라인에서 추적·기록할 수 있습니다.
- **Vault 부하 감소** — TTL 기반 응답 캐시가 반복되는 KV 조회를 Vault 호출 없이 처리합니다.
- **클러스터 토폴로지 은닉** — Client는 Vault 클러스터 구성이나 Active 노드를 알 필요가 없습니다.
- **일관된 거버넌스** — Rate Limiting, 감사 로그, 네트워크 정책 등 Kong Plugin을 단일 경계에 적용할 수 있습니다.

## 설치

```bash
luarocks make kong-vault-proxy-0.1.0-1.rockspec
export KONG_PLUGINS="bundled,kong-vault-proxy"
export KONG_NGINX_HTTP_LUA_SHARED_DICT="kong_vault_proxy_cache 33m"
```

## 로컬 데모

```bash
./demo/up.sh
./demo/ui/serve.sh   # http://127.0.0.1:3090
```

UI는 English/한국어 전환과 수동 Play·자동 요청을 지원합니다.

- 수동 Client: `/secret/data/...`에서 `key-auth` + ACL 적용
- 자동 App: `vault-app-key`로 `/app/...` Route만 접근, 플러그인이 Vault 인증
- Vault UI: `http://127.0.0.1:18200/ui/`
- 관리자: `admin` / `password` (`admin` policy)
- Trace: `http://localhost:16686`
- Log: `http://localhost:3000/d/kong-logs-compare/kong-logs-compare`

## 검증

```bash
export PROXY_URL="${PROXY_URL:-http://localhost:8000}"
./scripts/verify.sh
```

## 주요 설정

| 필드 | 설명 |
|---|---|
| `token_mode` | `force` / `auto` / `passthrough` |
| `auth_method` | `token` / `approle` / `kubernetes` |
| `vault_addrs` | login·renew 주소 |
| `cache.kv_min_cache_ttl` | KV 최소 캐시 시간(초) |
| `cache.default_ttl` | 기본 캐시 시간(초) |
| `cache.neg_ttl` | 오류 응답 캐시 시간(초) |
