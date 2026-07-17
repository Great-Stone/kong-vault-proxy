local cjson = require "cjson.safe"
local vault_http = require "kong.plugins.kong-vault-proxy.http"

local _M = {}

local function read_secret_id(conf)
  if conf.approle_secret_id and conf.approle_secret_id ~= "" then
    return conf.approle_secret_id
  end
  local path = conf.approle_secret_id_file
  if not path or path == "" then
    return nil, "approle requires approle_secret_id or approle_secret_id_file"
  end
  local f, err = io.open(path, "r")
  if not f then
    return nil, "cannot read approle_secret_id_file: " .. tostring(err)
  end
  local content = f:read("*a")
  f:close()
  content = content and content:gsub("%s+$", "")
  if not content or content == "" then
    return nil, "empty approle_secret_id_file"
  end
  return content
end

function _M.login(conf)
  local secret_id, err = read_secret_id(conf)
  if not secret_id then
    return nil, err
  end

  local mount = (conf.approle_auth_path or "approle"):gsub("^/", ""):gsub("/$", "")
  local body = cjson.encode({
    role_id = conf.approle_role_id,
    secret_id = secret_id,
  })

  local res, req_err = vault_http.request(conf, {
    method = "POST",
    path = "/v1/auth/" .. mount .. "/login",
    body = body,
  })
  if not res then
    return nil, req_err
  end
  if res.status ~= 200 then
    return nil, "approle login status " .. res.status .. ": " .. tostring(res.body)
  end

  local decoded = vault_http.decode_json(res.body)
  if not decoded or not decoded.auth or not decoded.auth.client_token then
    return nil, "approle login: missing client_token"
  end

  return decoded.auth.client_token, nil, decoded.auth.lease_duration or 0
end

return _M
