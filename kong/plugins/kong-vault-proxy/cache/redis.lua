local cjson = require "cjson.safe"
local redis = require "resty.redis"

local _M = {}

local function prefix(conf)
  local p = conf.cache and conf.cache.redis and conf.cache.redis.key_prefix
  return (p and p ~= "" and p) or "kong_vault_proxy:"
end

local function idx_key(conf, path)
  return prefix(conf) .. "idx:" .. (path or "/")
end

local function connect(conf)
  local rconf = conf.cache and conf.cache.redis or {}
  local red = redis:new()
  local timeout = rconf.timeout or 2000
  red:set_timeout(timeout)

  local host = rconf.host or "127.0.0.1"
  local port = rconf.port or 6379
  local ok, err = red:connect(host, port)
  if not ok then
    return nil, err
  end

  if rconf.password and rconf.password ~= "" then
    local aok, aerr = red:auth(rconf.password)
    if not aok then
      return nil, aerr
    end
  end

  local db = rconf.database or 0
  if db ~= 0 then
    local sok, serr = red:select(db)
    if not sok then
      return nil, serr
    end
  end
  return red
end

local function keepalive(red)
  if red then
    red:set_keepalive(10000, 100)
  end
end

function _M.get(conf, key)
  local red, err = connect(conf)
  if not red then
    return nil, err
  end
  local rkey = prefix(conf) .. key
  local raw, gerr = red:get(rkey)
  keepalive(red)
  if not raw or raw == ngx.null then
    return nil, gerr
  end
  return cjson.decode(raw)
end

function _M.set(conf, key, entry, ttl, path)
  local red, err = connect(conf)
  if not red then
    return nil, err
  end
  if not ttl or ttl < 1 then
    ttl = 1
  end
  local encoded, encode_err = cjson.encode(entry)
  if not encoded then
    keepalive(red)
    return nil, encode_err
  end

  local rkey = prefix(conf) .. key
  local ok, serr = red:setex(rkey, ttl, encoded)
  if not ok then
    keepalive(red)
    return nil, serr
  end

  if path and path ~= "" then
    local ik = idx_key(conf, path)
    red:sadd(ik, key)
    red:expire(ik, math.max(ttl, 3600))
  end
  keepalive(red)
  return true
end

function _M.delete(conf, key)
  local red, err = connect(conf)
  if not red then
    return nil, err
  end
  red:del(prefix(conf) .. key)
  keepalive(red)
  return true
end

function _M.clear_by_path(conf, path)
  local red, err = connect(conf)
  if not red then
    return nil, err
  end
  local ik = idx_key(conf, path)
  local members = red:smembers(ik)
  if type(members) == "table" then
    for i = 1, #members do
      red:del(prefix(conf) .. members[i])
    end
  end
  red:del(ik)
  keepalive(red)
  return true
end

function _M.clear_all(conf)
  local red, err = connect(conf)
  if not red then
    return nil, err
  end
  local p = prefix(conf)
  local cursor = "0"
  repeat
    local res, scan_err = red:scan(cursor, "MATCH", p .. "*", "COUNT", 100)
    if not res then
      keepalive(red)
      return nil, scan_err
    end
    cursor = res[1]
    local keys = res[2]
    if type(keys) == "table" then
      for i = 1, #keys do
        red:del(keys[i])
      end
    end
  until cursor == "0"
  keepalive(red)
  return true
end

return _M
