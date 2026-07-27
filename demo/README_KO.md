# 데모 (로컬 e2e)

3노드 Vault Raft와 Kong Enterprise(`kong-net`)로 `kong-vault-proxy` AppRole 인증, 토큰 갱신, 캐시 무효화, failover를 검증합니다.

## 사전 조건

- 실행 중인 `kong-enterprise/docker` (`kong-net`, Admin `:8001`, Proxy `:8000`)
- `deck`, `jq`, `docker`

## 실행

```bash
./start.sh
```

Vault 초기화·unseal, AppRole 구성, 플러그인 마운트(토큰·캐시 shm), workspace `kong-vault-proxy`에 decK sync, AppRole 로그인 warm-up까지 수행합니다.

검증은 별도로 실행합니다.

```bash
./test.sh
```

## Flow UI

```bash
./ui/serve.sh
# http://127.0.0.1:3090
```

app-a/app-b, ACL 거부, cache MISS→HIT, cache bypass, Auto App 시나리오를 제공합니다. 요청에 `X-Vault-Request: true`를 포함합니다.

## 검증 항목

1. `key-auth`·Route·ACL로 Client/App 격리
2. `X-Vault-Request` 누락 시 412
3. 캐시 HIT 및 KV write 무효화
4. AppRole Secret ID 재사용 거부
5. periodic 토큰 4/5 갱신
6. Vault 리더 장애·복구 중 프록시 가용성

## 정리

```bash
./stop.sh
```

[English](README.md)
