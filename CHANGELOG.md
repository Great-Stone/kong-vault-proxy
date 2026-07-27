# CHANGELOG

## 0.2.0

### Feature
- Add memory and redis response-cache strategies
- Cap dynamic-secret cache TTL to Vault lease_duration
- Invalidate cache on mutating Vault requests and cache-clear API
- Use standby-capable /sys/health for Upstream and auth probes
- Expose Prometheus counters for auth and cache
- Add demo start/stop scripts and dedicated Kong workspace
- Bypass response cache with X-Kong-Vault-Proxy-Bypass-Cache
- Add Vault Proxy-style POST cache-clear API and demo scene

### Security
- Add optional require_vault_request_header (412 when missing)

## 0.1.0

### Feature
- Initial Vault API proxy with AppRole/Kubernetes/token auto-auth and TTL cache
