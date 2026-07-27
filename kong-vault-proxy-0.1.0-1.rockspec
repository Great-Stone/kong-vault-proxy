package = "kong-vault-proxy"
version = "0.1.0-1"

source = {
  url = "git+https://github.com/Great-Stone/kong-vault-proxy.git",
  tag = "0.1.0",
}

description = {
  summary  = "Vault API proxy with auto-auth, token renewal, and TTL caching for Kong Gateway",
  detailed = [[
    Proxies client requests to HashiCorp Vault with Vault Proxy-like
    auto-auth, token renewal, and response caching. Cluster LB and
    health checks are left to Kong Upstream + Targets.
  ]],
  license  = "MIT",
}

dependencies = {
  "lua >= 5.1",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins.kong-vault-proxy.handler"]         = "kong/plugins/kong-vault-proxy/handler.lua",
    ["kong.plugins.kong-vault-proxy.schema"]          = "kong/plugins/kong-vault-proxy/schema.lua",
    ["kong.plugins.kong-vault-proxy.http"]            = "kong/plugins/kong-vault-proxy/http.lua",
    ["kong.plugins.kong-vault-proxy.auth"]            = "kong/plugins/kong-vault-proxy/auth.lua",
    ["kong.plugins.kong-vault-proxy.auth.token"]      = "kong/plugins/kong-vault-proxy/auth/token.lua",
    ["kong.plugins.kong-vault-proxy.auth.approle"]    = "kong/plugins/kong-vault-proxy/auth/approle.lua",
    ["kong.plugins.kong-vault-proxy.auth.kubernetes"] = "kong/plugins/kong-vault-proxy/auth/kubernetes.lua",
    ["kong.plugins.kong-vault-proxy.token"]           = "kong/plugins/kong-vault-proxy/token.lua",
    ["kong.plugins.kong-vault-proxy.cache"]           = "kong/plugins/kong-vault-proxy/cache.lua",
  },
}
