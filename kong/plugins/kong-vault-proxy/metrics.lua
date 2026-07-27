local _M = {}

local counters = {}

function _M.init_worker()
  local ok, exporter = pcall(require, "kong.plugins.prometheus.exporter")
  if not ok or not exporter or not exporter.get_prometheus then
    return
  end
  local prometheus = exporter.get_prometheus()
  if not prometheus then
    return
  end

  counters.auth_success = prometheus:counter(
    "kong_vault_proxy_auth_success",
    "Vault auto-auth login successes")
  counters.auth_failure = prometheus:counter(
    "kong_vault_proxy_auth_failure",
    "Vault auto-auth login failures")
  counters.cache_hit = prometheus:counter(
    "kong_vault_proxy_cache_hit",
    "Vault proxy response cache hits")
  counters.cache_miss = prometheus:counter(
    "kong_vault_proxy_cache_miss",
    "Vault proxy response cache misses")
  counters.renew_failure = prometheus:counter(
    "kong_vault_proxy_renew_failure",
    "Vault token renew-self failures")
end

local function inc(name)
  local c = counters[name]
  if c then
    c:inc(1)
  end
end

function _M.auth_success()
  inc("auth_success")
end

function _M.auth_failure()
  inc("auth_failure")
end

function _M.cache_hit()
  inc("cache_hit")
end

function _M.cache_miss()
  inc("cache_miss")
end

function _M.renew_failure()
  inc("renew_failure")
end

return _M
