local handlers = {
  token = require "kong.plugins.kong-vault-proxy.auth.token",
  approle = require "kong.plugins.kong-vault-proxy.auth.approle",
  kubernetes = require "kong.plugins.kong-vault-proxy.auth.kubernetes",
}

local _M = {}

--- Login and return client_token, err, lease_duration (seconds).
function _M.login(conf)
  local h = handlers[conf.auth_method]
  if not h then
    return nil, "unsupported auth_method: " .. tostring(conf.auth_method)
  end
  return h.login(conf)
end

return _M
