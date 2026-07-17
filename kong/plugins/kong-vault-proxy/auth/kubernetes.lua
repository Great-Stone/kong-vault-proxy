local cjson = require "cjson.safe"
local vault_http = require "kong.plugins.kong-vault-proxy.http"

local _M = {}

local function read_sa_jwt(path)
  local f, err = io.open(path, "r")
  if not f then
    return nil, err
  end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then
    return nil, "empty kube service account token"
  end
  return (content:gsub("%s+$", ""))
end

function _M.login(conf)
  local jwt, err = read_sa_jwt(
    conf.kube_api_token_file or "/run/secrets/kubernetes.io/serviceaccount/token"
  )
  if not jwt then
    return nil, "kubernetes auth: " .. tostring(err)
  end

  local mount = (conf.kube_auth_path or "kubernetes"):gsub("^/", ""):gsub("/$", "")
  local body = cjson.encode({
    jwt = jwt,
    role = conf.kube_role,
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
    return nil, "kubernetes login status " .. res.status .. ": " .. tostring(res.body)
  end

  local decoded = vault_http.decode_json(res.body)
  if not decoded or not decoded.auth or not decoded.auth.client_token then
    return nil, "kubernetes login: missing client_token"
  end

  return decoded.auth.client_token, nil, decoded.auth.lease_duration or 0
end

return _M
