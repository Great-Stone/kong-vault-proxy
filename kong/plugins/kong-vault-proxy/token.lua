local auth = require "kong.plugins.kong-vault-proxy.auth"
local vault_http = require "kong.plugins.kong-vault-proxy.http"
local metrics = require "kong.plugins.kong-vault-proxy.metrics"
local cjson = require "cjson.safe"
local resty_sha256 = require "resty.sha256"
local str = require "resty.string"
local resty_lock = require "resty.lock"

local TOKEN_DICT = "kong_vault_proxy_tokens"
-- Vault Agent-style renewal: renew at 4/5 of the current lease.
local RENEW_RATIO = 0.8
local MIN_RENEW_DELAY = 5
local MAX_RENEW_DELAY = 3600

local _M = {}
local active = {}

local function conf_key(conf)
  local identity = table.concat({
    conf.vault_scheme or "http",
    table.concat(conf.vault_addrs, ","),
    conf.namespace or "",
    conf.auth_method or "",
    conf.token or "",
    conf.approle_auth_path or "",
    conf.approle_role_id or "",
    conf.approle_secret_id or "",
    conf.approle_secret_id_file or "",
    conf.kube_auth_path or "",
    conf.kube_role or "",
    conf.kube_api_token_file or "",
  }, "\0")
  local sha = resty_sha256:new()
  sha:update(identity)
  return "tok:" .. str.to_hex(sha:final())
end

local function started_key(conf)
  return "started:" .. conf_key(conf)
end

local function dict()
  return ngx.shared[TOKEN_DICT]
end

local function acquire_auth_lock(conf)
  local lock, err = resty_lock:new(TOKEN_DICT, {
    timeout = 5,
    exptime = 30,
  })
  if not lock then
    return nil, err
  end
  local _, lock_err = lock:lock("auth:" .. conf_key(conf))
  if lock_err then
    return nil, lock_err
  end
  return lock
end

function _M.get(conf)
  local d = dict()
  if not d then
    return nil, "shared dict '" .. TOKEN_DICT .. "' not found"
  end
  local raw = d:get(conf_key(conf))
  if not raw then
    return nil
  end
  local data = cjson.decode(raw)
  if not data or not data.token then
    return nil
  end
  return data.token, data.lease_duration
end

function _M.set(conf, token, lease_duration)
  local d = dict()
  if not d then
    return nil, "shared dict '" .. TOKEN_DICT .. "' not found"
  end
  local ttl = lease_duration and lease_duration > 0 and (lease_duration + 60) or 86400
  local ok, err = d:set(conf_key(conf), cjson.encode({
    token = token,
    lease_duration = lease_duration or 0,
    stored_at = ngx.now(),
  }), ttl)
  if not ok then
    return nil, err
  end
  return true
end

function _M.login_and_store(conf)
  local token, err, lease = auth.login(conf)
  if not token then
    metrics.auth_failure()
    return nil, err
  end
  local ok, set_err = _M.set(conf, token, lease)
  if not ok then
    metrics.auth_failure()
    return nil, set_err
  end
  metrics.auth_success()
  return token, nil, lease
end

local function renew_delay(lease_duration)
  if not lease_duration or lease_duration <= 0 then
    return 60
  end
  local d = math.floor(lease_duration * RENEW_RATIO)
  if d < MIN_RENEW_DELAY then
    d = MIN_RENEW_DELAY
  end
  if d > MAX_RENEW_DELAY then
    d = MAX_RENEW_DELAY
  end
  return d
end

local function renew_self(conf, token)
  local res, err = vault_http.request(conf, {
    method = "POST",
    path = "/v1/auth/token/renew-self",
    token = token,
  })
  if not res then
    return nil, err
  end
  if res.status ~= 200 then
    return nil, "renew-self status " .. res.status .. ": " .. tostring(res.body)
  end
  local decoded = vault_http.decode_json(res.body)
  local new_token = token
  local lease = 0
  if decoded and decoded.auth then
    new_token = decoded.auth.client_token or token
    lease = decoded.auth.lease_duration or 0
  end
  return new_token, nil, lease
end

local function schedule(conf, delay)
  local d = dict()
  if not d then
    return
  end
  if not d:add(started_key(conf), true, math.max(delay + 30, 30)) then
    return
  end

  local ok, err = ngx.timer.at(delay, function(premature)
    if premature then
      return
    end
    d:delete(started_key(conf))
    if active[conf_key(conf)] then
      _M.renew_or_relogin(conf)
    end
  end)
  if not ok then
    d:delete(started_key(conf))
    kong.log.err("[kong-vault-proxy] failed to schedule token renew: ", err)
  end
end

function _M.renew_or_relogin(conf)
  local lock, lock_err = acquire_auth_lock(conf)
  if not lock then
    kong.log.warn("[kong-vault-proxy] token lock failed: ", lock_err)
    schedule(conf, MIN_RENEW_DELAY)
    return
  end

  local token = _M.get(conf)
  local lease = 0

  if token then
    local new_token, err, new_lease = renew_self(conf, token)
    if new_token then
      token, lease = new_token, new_lease or 0
      _M.set(conf, token, lease)
      kong.log.notice("[kong-vault-proxy] token renewed, lease=", lease)
    else
      metrics.renew_failure()
      kong.log.warn("[kong-vault-proxy] renew-self failed, re-login: ", err)
      token = nil
    end
  end

  if not token then
    local t, err, l = _M.login_and_store(conf)
    if not t then
      kong.log.err("[kong-vault-proxy] login failed: ", err)
      lock:unlock()
      schedule(conf, MIN_RENEW_DELAY)
      return
    end
    token, lease = t, l or 0
    kong.log.notice("[kong-vault-proxy] logged in, lease=", lease)
  end

  lock:unlock()
  schedule(conf, renew_delay(lease))
end

--- Ensure a token is available (sync). Starts renew loop once per conf.
function _M.ensure(conf)
  if conf.token_mode == "passthrough" then
    return nil
  end
  active[conf_key(conf)] = true

  local d = dict()
  if not d then
    return nil, "shared dict '" .. TOKEN_DICT .. "' not found; set KONG_NGINX_HTTP_LUA_SHARED_DICT"
  end

  local token, err = _M.get(conf)
  if token then
    _M.start_renew_loop(conf)
    return token
  end

  local lock, lock_err = acquire_auth_lock(conf)
  if not lock then
    return nil, "token lock failed: " .. tostring(lock_err)
  end

  -- configure timer or another request may have logged in while we waited.
  token = _M.get(conf)
  if token then
    lock:unlock()
    _M.start_renew_loop(conf)
    return token
  end

  token, err = _M.login_and_store(conf)
  lock:unlock()
  if not token then
    return nil, err
  end
  _M.start_renew_loop(conf)
  return token
end

function _M.start_renew_loop(conf)
  if conf.token_mode == "passthrough" then
    return
  end
  local _, lease = _M.get(conf)
  schedule(conf, renew_delay(lease))
end

function _M.configure(configs)
  local next_active = {}
  if configs then
    for i = 1, #configs do
      local conf = configs[i]
      if conf.token_mode ~= "passthrough" then
        next_active[conf_key(conf)] = true
      end
    end
  end
  active = next_active
end

_M.DICT = TOKEN_DICT
_M.conf_key = conf_key

return _M
