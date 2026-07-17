local cjson = require "cjson.safe"
local resty_sha256 = require "resty.sha256"
local str = require "resty.string"

local CACHE_DICT = "kong_vault_proxy_cache"

local _M = {}

_M.DICT = CACHE_DICT

local function dict()
  return ngx.shared[CACHE_DICT]
end

function _M.is_cacheable(conf, method)
  if not conf.cache or not conf.cache.enabled then
    return false
  end
  method = string.upper(method or "")
  for _, m in ipairs(conf.cacheable_methods or {}) do
    if m == method then
      return true
    end
  end
  return false
end

local function fingerprint(token)
  if not token or token == "" then
    return "none"
  end
  local sha = resty_sha256:new()
  sha:update(token)
  return str.to_hex(sha:final()):sub(1, 16)
end

function _M.key(method, path, query, namespace, token)
  local raw = table.concat({
    string.upper(method or "GET"),
    path or "/",
    query or "",
    namespace or "",
    fingerprint(token),
  }, "|")
  local sha = resty_sha256:new()
  sha:update(raw)
  return "c:" .. str.to_hex(sha:final())
end

function _M.get(key)
  local d = dict()
  if not d then
    return nil
  end
  local raw = d:get(key)
  if not raw then
    return nil
  end
  return cjson.decode(raw)
end

function _M.set(key, entry, ttl)
  local d = dict()
  if not d then
    return nil, "shared dict '" .. CACHE_DICT .. "' not found"
  end
  if not ttl or ttl < 1 then
    ttl = 1
  end
  local encoded, encode_err = cjson.encode(entry)
  if not encoded then
    return nil, encode_err
  end
  local ok, err = d:set(key, encoded, ttl)
  if not ok then
    return nil, err
  end
  return true
end

--- Compute cache TTL from Vault JSON body + config.
function _M.compute_ttl(conf, status, body_json)
  local cache = conf.cache
  if status >= 400 then
    return cache.neg_ttl
  end

  local lease = 0
  local renewable = false
  if body_json then
    if type(body_json.lease_duration) == "number" then
      lease = body_json.lease_duration
    end
    renewable = body_json.renewable == true
  end

  if lease > 0 and renewable then
    return math.max(lease, 1)
  end

  local base = lease > 0 and lease or cache.default_ttl
  return math.max(base, cache.kv_min_cache_ttl)
end

return _M
