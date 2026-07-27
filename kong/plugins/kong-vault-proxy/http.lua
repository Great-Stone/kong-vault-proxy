local http = require "resty.http"
local cjson = require "cjson.safe"

local TOKEN_DICT = "kong_vault_proxy_tokens"
local RR_KEY = "kong_vault_proxy:rr"
local HEALTH_PATH = "/v1/sys/health?standbyok=true&perfstandbyok=true"
local HEALTH_TTL = 2
local HEALTH_PROBE_TIMEOUT = 2000

local _M = {}

_M.TOKEN_DICT = TOKEN_DICT
_M.HEALTH_PATH = HEALTH_PATH

local function parse_addr(addr)
  local host, port = addr:match("^%[(.-)%]:(%d+)$") -- [ipv6]:port
  if host then
    return host, tonumber(port)
  end
  host, port = addr:match("^([^:]+):(%d+)$")
  if host then
    return host, tonumber(port)
  end
  return addr, nil
end

local function health_cache_key(addr)
  return "health:" .. addr
end

--- Probe Vault /sys/health with standbyok+perfstandbyok. Cache result briefly in shm.
function _M.is_healthy(conf, addr)
  local dict = ngx.shared[TOKEN_DICT]
  if dict then
    local cached = dict:get(health_cache_key(addr))
    if cached == "1" then
      return true
    elseif cached == "0" then
      return false
    end
  end

  local scheme = conf.vault_scheme or "http"
  local url = scheme .. "://" .. addr .. HEALTH_PATH
  local client = http.new()
  client:set_timeouts(HEALTH_PROBE_TIMEOUT, HEALTH_PROBE_TIMEOUT, HEALTH_PROBE_TIMEOUT)

  local res, err = client:request_uri(url, {
    method = "GET",
    ssl_verify = conf.tls_verify,
  })

  local ok = res and res.status == 200
  if dict then
    dict:set(health_cache_key(addr), ok and "1" or "0", HEALTH_TTL)
  end
  if not ok and err then
    kong.log.warn("[kong-vault-proxy] health probe failed for ", addr, ": ", err)
  end
  return ok
end

function _M.next_addr(conf)
  local addrs = conf.vault_addrs
  if not addrs or #addrs == 0 then
    return nil, "vault_addrs is empty"
  end

  local dict = ngx.shared[TOKEN_DICT]
  local start = 0
  if dict then
    start = dict:incr(RR_KEY, 1, 0) or 0
  else
    start = math.floor(ngx.now() * 1000)
  end

  local n = #addrs
  for i = 0, n - 1 do
    local addr = addrs[((start + i) % n) + 1]
    if _M.is_healthy(conf, addr) then
      return addr
    end
  end

  return nil, "no healthy vault_addrs"
end

--- Request Vault with health-aware round-robin + skip on connection failure.
-- @return res, err, used_addr
function _M.request(conf, opts)
  opts = opts or {}
  local method = opts.method or "GET"
  local path = opts.path or "/"
  local body = opts.body
  local headers = opts.headers or {}
  local token = opts.token

  if conf.namespace and not headers["X-Vault-Namespace"] then
    headers["X-Vault-Namespace"] = conf.namespace
  end
  if token then
    headers["X-Vault-Token"] = token
  end
  if body and not headers["Content-Type"] then
    headers["Content-Type"] = "application/json"
  end

  local n = #conf.vault_addrs
  local last_err
  for _ = 1, n do
    local addr, pick_err = _M.next_addr(conf)
    if not addr then
      return nil, pick_err or last_err or "all vault_addrs failed"
    end

    local host, port = parse_addr(addr)
    local scheme = conf.vault_scheme or "http"
    local url = scheme .. "://" .. addr .. path

    local client = http.new()
    client:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)

    local res, err = client:request_uri(url, {
      method = method,
      body = body,
      headers = headers,
      ssl_verify = conf.tls_verify,
    })

    if not res then
      last_err = (err or "request failed") .. " (" .. tostring(host) .. ":" .. tostring(port or "?") .. ")"
      kong.log.warn("[kong-vault-proxy] vault request failed: ", last_err)
      local dict = ngx.shared[TOKEN_DICT]
      if dict then
        dict:set(health_cache_key(addr), "0", HEALTH_TTL)
      end
    else
      return res, nil, addr
    end
  end

  return nil, last_err or "all vault_addrs failed"
end

function _M.decode_json(body)
  if not body or body == "" then
    return nil
  end
  return cjson.decode(body)
end

return _M
