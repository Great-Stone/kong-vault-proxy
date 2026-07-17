# 데모 (로컬 e2e)

Vault 3노드(Raft)와 Kong Enterprise(`kong-net`)에서 `kong-vault-proxy`의 AppRole 인증·토큰 갱신·failover를 검증합니다.

## 사전 조건

- `kong-enterprise/docker` 기동 (`kong-net`, Admin `:8001`, Proxy `:8000`)
- `deck`, `jq`, `docker`

## 실행

```bash
./up.sh
```

Vault init/unseal, AppRole(one-shot Secret ID → orphan periodic token), Kong 플러그인 마운트, decK sync와 테스트를 수행합니다.

## Flow UI

```bash
./ui/serve.sh
# http://127.0.0.1:3090
```

![UI](kong-vault-proxy-demo-ui.png)

app-a, app-b, 교차 ACL 거부, cache MISS→HIT 시나리오와 Auto App을 제공합니다.

## 검증 항목

1. Client/App별 `key-auth`, Route, ACL 격리
2. AppRole Secret ID 재사용 거부
3. periodic token(`period=30s`)의 4/5 시점 연속 갱신
4. Vault leader 장애·복구 중 proxy 가용성

Vault UI: vault-1 `18200`, vault-2 `18202`, vault-3 `18203`

## 정리

```bash
./clean.sh
```

[English](README.md)
