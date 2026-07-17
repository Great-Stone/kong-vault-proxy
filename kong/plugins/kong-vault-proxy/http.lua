local http = require "resty.http"
local cjson = require "cjson.safe"

local TOKEN_DICT = "kong_vault_proxy_cache"
local RR_KEY = "kong_vault_proxy:rr"

local _M = {}

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

function _M.next_addr(conf)
  local addrs = conf.vault_addrs
  if not addrs or #addrs == 0 then
    return nil, "vault_addrs is empty"
  end
  if #addrs == 1 then
    return addrs[1]
  end

  local dict = ngx.shared[TOKEN_DICT]
  local idx = 0
  if dict then
    idx = dict:incr(RR_KEY, 1, 0) or 0
  else
    idx = math.floor(ngx.now() * 1000)
  end
  return addrs[(idx % #addrs) + 1]
end

--- Request Vault with round-robin + skip on connection failure.
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
    local addr = _M.next_addr(conf)
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
