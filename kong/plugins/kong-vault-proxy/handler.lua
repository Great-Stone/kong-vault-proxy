local token_mgr = require "kong.plugins.kong-vault-proxy.token"
local cache = require "kong.plugins.kong-vault-proxy.cache"
local cjson = require "cjson.safe"

local KongVaultProxyHandler = {
  PRIORITY = 800,
  VERSION = "0.1.0",
}

local function client_vault_token()
  return kong.request.get_header("X-Vault-Token")
end

local function resolve_token(conf)
  local mode = conf.token_mode
  local client = client_vault_token()

  if mode == "passthrough" then
    return client
  end

  if mode == "auto" and client and client ~= "" then
    return client
  end

  local t, err = token_mgr.ensure(conf)
  if not t then
    return nil, err or "auto-auth token unavailable"
  end
  return t
end

local function pick_headers_for_cache(headers)
  local out = {}
  if not headers then
    return out
  end
  for k, v in pairs(headers) do
    local lk = string.lower(k)
    if lk == "content-type" or lk == "cache-control" or lk == "x-vault-index" then
      if type(v) == "table" then
        out[k] = v[1]
      else
        out[k] = v
      end
    end
  end
  return out
end

-- Map upstream peer IP → vault-N:8200 via Kong DNS on vault_addrs.
local ip_to_vault = {}

local function lookup_host(host)
  if kong.dns and kong.dns.toip then
    local ip = kong.dns.toip(host)
    if ip then return ip end
  end
  local ok, dns = pcall(require, "resty.dns.client")
  if ok and dns.toip then
    local ip = dns.toip(host)
    if ip then return ip end
  end
  return nil
end

local function resolve_vault_map(conf)
  if next(ip_to_vault) then
    return
  end
  for _, addr in ipairs(conf.vault_addrs or {}) do
    local host, port = addr:match("^([^:]+):(%d+)$")
    if host then
      local ip = lookup_host(host)
      if type(ip) == "string" and ip ~= "" then
        ip_to_vault[ip] = host .. ":" .. port
        ip_to_vault[ip .. ":" .. port] = host .. ":" .. port
      end
    end
  end
end

local function upstream_vault_peer(conf)
  local raw = ngx.var.upstream_addr or ""
  local peer = raw:match("([^,%s]+)%s*$") or raw
  if conf then
    resolve_vault_map(conf)
    if ip_to_vault[peer] then
      return ip_to_vault[peer]
    end
    local ip = peer:match("^([^:]+)")
    if ip and ip_to_vault[ip] then
      return ip_to_vault[ip]
    end
  end
  local bd = ngx.ctx.balancer_data
  if bd and bd.ip then
    local key = tostring(bd.ip) .. (bd.port and (":" .. tostring(bd.port)) or "")
    if conf then
      resolve_vault_map(conf)
      if ip_to_vault[key] then return ip_to_vault[key] end
      if ip_to_vault[tostring(bd.ip)] then return ip_to_vault[tostring(bd.ip)] end
    end
    return key
  end
  return peer
end

function KongVaultProxyHandler:configure(configs)
  ip_to_vault = {}
  token_mgr.configure(configs)
end

function KongVaultProxyHandler:access(conf)
  local vault_token, err = resolve_token(conf)
  if conf.token_mode == "force" and not vault_token then
    return kong.response.exit(502, {
      message = "kong-vault-proxy auto-auth failed",
      error = err,
    })
  end
  if conf.token_mode == "auto" and not client_vault_token() and not vault_token then
    return kong.response.exit(502, {
      message = "kong-vault-proxy auto-auth failed",
      error = err,
    })
  end

  if conf.token_mode == "force" then
    kong.service.request.clear_header("X-Vault-Token")
    kong.service.request.set_header("X-Vault-Token", vault_token)
  elseif conf.token_mode == "auto" and not client_vault_token() then
    kong.service.request.set_header("X-Vault-Token", vault_token)
  end

  if conf.namespace and conf.namespace ~= "" then
    if not kong.request.get_header("X-Vault-Namespace") then
      kong.service.request.set_header("X-Vault-Namespace", conf.namespace)
    end
  end

  local method = kong.request.get_method()
  if not cache.is_cacheable(conf, method) then
    return
  end

  local service = kong.router.get_service()
  local path = kong.request.get_path()
  local qs = kong.request.get_raw_query()
  local ns = kong.request.get_header("X-Vault-Namespace") or conf.namespace or ""
  local key = cache.key(method, (service and service.id or "") .. ":" .. path,
                        qs, ns, vault_token)

  local hit = cache.get(key)
  if hit then
    local headers = hit.headers or {}
    headers["X-Kong-Vault-Proxy-Cache"] = "HIT"
    -- ponytail: HIT skips upstream — UI should not light a Vault node
    headers["X-Kong-Vault-Proxy-Vault"] = "cache"
    return kong.response.exit(hit.status, hit.body, headers)
  end

  kong.ctx.plugin.cache_key = key
  kong.ctx.plugin.cache_conf = true
  kong.service.request.enable_buffering()
end

function KongVaultProxyHandler:response(conf)
  local peer = upstream_vault_peer(conf)
  if peer ~= "" then
    kong.response.set_header("X-Kong-Vault-Proxy-Vault", peer)
  end

  if not kong.ctx.plugin.cache_conf then
    return
  end

  local status = kong.service.response.get_status()
  local body = kong.service.response.get_raw_body()
  local headers = pick_headers_for_cache(kong.service.response.get_headers())
  if peer ~= "" then
    headers["X-Kong-Vault-Proxy-Vault"] = peer
  end

  local body_json = cjson.decode(body or "")
  local ttl = cache.compute_ttl(conf, status, body_json)

  local ok, err = cache.set(kong.ctx.plugin.cache_key, {
    status = status,
    body = body or "",
    headers = headers,
  }, ttl)

  if not ok then
    kong.log.warn("[kong-vault-proxy] cache set failed: ", err)
  end

  kong.response.set_header("X-Kong-Vault-Proxy-Cache", "MISS")
end

return KongVaultProxyHandler
