--- Static token auth: conf.token is the Vault client token.
local _M = {}

function _M.login(conf)
  if not conf.token or conf.token == "" then
    return nil, "token auth_method requires config.token"
  end
  -- lease unknown for static tokens; renew timer will probe renew-self
  return conf.token, nil, conf.cache and conf.cache.default_ttl or 300
end

return _M
