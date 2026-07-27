local resty_sha256 = require "resty.sha256"
local str = require "resty.string"
local memory = require "kong.plugins.kong-vault-proxy.cache.memory"
local redis_store = require "kong.plugins.kong-vault-proxy.cache.redis"

local _M = {}

local MUTATING = {
  POST = true,
  PUT = true,
  PATCH = true,
  DELETE = true,
}

local function store_for(conf)
  local strategy = conf.cache and conf.cache.strategy or "memory"
  if strategy == "redis" then
    return redis_store
  end
  return memory
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

function _M.is_mutating(method)
  return MUTATING[string.upper(method or "")] == true
end

local function fingerprint(token)
  if not token or token == "" then
    return "none"
  end
  local sha = resty_sha256:new()
  sha:update(token)
  return str.to_hex(sha:final()):sub(1, 16)
end

function _M.fingerprint_token(token)
  return fingerprint(token)
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

--- Paths to invalidate for a Vault request path (includes KV v2 data sibling).
function _M.invalidate_paths(path)
  local paths = {}
  if not path or path == "" then
    return paths
  end
  paths[#paths + 1] = path
  -- KV v2: /secret/data/foo ↔ metadata writes still use data path reads
  local data_path = path:match("^(.-)/data/(.+)$")
  if data_path then
    -- already data path
  else
    local meta = path:match("^(.-)/metadata/(.+)$")
    if meta then
      local mount, rest = path:match("^(.-)/metadata/(.+)$")
      if mount and rest then
        paths[#paths + 1] = mount .. "/data/" .. rest
      end
    end
  end
  return paths
end

function _M.get(conf, key)
  local store = store_for(conf)
  local entry, err = store.get(conf, key)
  if err then
    kong.log.warn("[kong-vault-proxy] cache get failed: ", err)
    return nil
  end
  return entry
end

function _M.set(conf, key, entry, ttl, path)
  local store = store_for(conf)
  local ok, err = store.set(conf, key, entry, ttl, path)
  if not ok then
    return nil, err
  end
  return true
end

function _M.invalidate_path(conf, path)
  local store = store_for(conf)
  for _, p in ipairs(_M.invalidate_paths(path)) do
    local ok, err = store.clear_by_path(conf, p)
    if not ok then
      kong.log.warn("[kong-vault-proxy] cache invalidate failed: ", err)
    end
  end
  return true
end

function _M.clear(conf, typ, value)
  local store = store_for(conf)
  if typ == "all" then
    return store.clear_all(conf)
  end
  if typ == "request_path" then
    return store.clear_by_path(conf, value)
  end
  if typ == "token" then
    -- ponytail: token clear flushes all; per-token index upgrade path if needed
    return store.clear_all(conf)
  end
  return nil, "unsupported clear type: " .. tostring(typ)
end

--- Compute cache TTL from Vault JSON body + config.
-- Leased secrets: TTL must not exceed lease_duration.
function _M.compute_ttl(conf, status, body_json)
  local cache = conf.cache
  if status >= 400 then
    return cache.neg_ttl
  end

  local lease = 0
  if body_json and type(body_json.lease_duration) == "number" then
    lease = body_json.lease_duration
  end

  if lease > 0 then
    return math.max(lease, 1)
  end

  return math.max(cache.default_ttl, cache.kv_min_cache_ttl)
end

-- assert-based self-check (ponytail: fails if lease TTL logic regresses)
do
  local conf = {
    cache = { neg_ttl = 5, default_ttl = 300, kv_min_cache_ttl = 30 },
  }
  assert(_M.compute_ttl(conf, 200, { lease_duration = 60 }) == 60,
         "leased TTL must equal lease_duration")
  assert(_M.compute_ttl(conf, 200, { lease_duration = 10 }) == 10,
         "leased TTL must not use kv_min_cache_ttl")
  assert(_M.compute_ttl(conf, 200, {}) == 300,
         "static TTL uses max(default, kv_min)")
  assert(_M.compute_ttl(conf, 404, {}) == 5, "neg_ttl for errors")
end

return _M
