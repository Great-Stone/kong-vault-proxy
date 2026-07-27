local cjson = require "cjson.safe"

local _M = {}

local function dict(conf)
  local name = (conf.cache and conf.cache.memory and conf.cache.memory.dictionary_name)
                or "kong_vault_proxy_cache"
  return ngx.shared[name], name
end

local function idx_key(path)
  return "idx:" .. (path or "/")
end

function _M.get(conf, key)
  local d, name = dict(conf)
  if not d then
    return nil, "shared dict '" .. name .. "' not found"
  end
  local raw = d:get(key)
  if not raw then
    return nil
  end
  return cjson.decode(raw)
end

function _M.set(conf, key, entry, ttl, path)
  local d, name = dict(conf)
  if not d then
    return nil, "shared dict '" .. name .. "' not found"
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

  if path and path ~= "" then
    local ik = idx_key(path)
    local raw = d:get(ik)
    local list = raw and cjson.decode(raw) or {}
    local seen = false
    for i = 1, #list do
      if list[i] == key then
        seen = true
        break
      end
    end
    if not seen then
      list[#list + 1] = key
    end
    -- ponytail: index TTL = max entry TTL ceiling; upgrade to per-key index if cardinality grows
    d:set(ik, cjson.encode(list), math.max(ttl, 3600))
  end
  return true
end

function _M.delete(conf, key)
  local d = dict(conf)
  if not d then
    return true
  end
  d:delete(key)
  return true
end

function _M.clear_by_path(conf, path)
  local d = dict(conf)
  if not d or not path or path == "" then
    return true
  end
  local ik = idx_key(path)
  local raw = d:get(ik)
  if raw then
    local list = cjson.decode(raw) or {}
    for i = 1, #list do
      d:delete(list[i])
    end
    d:delete(ik)
  end
  return true
end

function _M.clear_all(conf)
  local d, name = dict(conf)
  if not d then
    return nil, "shared dict '" .. name .. "' not found"
  end
  d:flush_all()
  d:flush_expired()
  return true
end

return _M
