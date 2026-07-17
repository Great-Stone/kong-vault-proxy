local typedefs = require "kong.db.schema.typedefs"

-- ponytail: v0.1 auth surface = token/approle/kubernetes only; add jwt/gcp/azure/aws/cert like HCV when needed.

local function validate_vault_addr(addr)
  local ipv6, port = addr:match("^%[(.+)%]:(%d+)$")
  if ipv6 and not ipv6:find(":", 1, true) then
    return false, "brackets are only valid for IPv6 addresses"
  end
  port = port or addr:match("^[^:%s/]+:(%d+)$")
  port = tonumber(port)
  if not port or port < 1 or port > 65535 then
    return false, "must be host:port or [ipv6]:port"
  end
  return true
end

local function validate_config(config)
  if config.auth_method == "approle" then
    local sid = config.approle_secret_id
    local file = config.approle_secret_id_file
    local has_sid = sid and sid ~= "" and sid ~= ngx.null
    local has_file = file and file ~= "" and file ~= ngx.null
    if not has_sid and not has_file then
      return false, "must set one of approle_secret_id, approle_secret_id_file when auth_method is approle"
    end
  end
  return true
end

return {
  name = "kong-vault-proxy",
  fields = {
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { token_mode = {
              type = "string",
              one_of = { "auto", "force", "passthrough" },
              default = "force",
              required = true,
          } },
          { auth_method = {
              type = "string",
              one_of = { "token", "approle", "kubernetes" },
              default = "token",
              required = true,
          } },
          { vault_addrs = {
              type = "array",
              required = true,
              elements = {
                type = "string",
                custom_validator = validate_vault_addr,
              },
              len_min = 1,
          } },
          { vault_scheme = {
              type = "string",
              one_of = { "http", "https" },
              default = "http",
          } },
          { namespace = { type = "string", required = false } },
          { tls_verify = { type = "boolean", required = true, default = true } },
          { connect_timeout = { type = "number", default = 5000, gt = 0 } },
          { send_timeout = { type = "number", default = 5000, gt = 0 } },
          { read_timeout = { type = "number", default = 10000, gt = 0 } },

          -- Token auth
          { token = { type = "string", required = false, encrypted = true, referenceable = true } },

          -- AppRole auth
          { approle_auth_path = { type = "string", default = "approle" } },
          { approle_role_id = { type = "string", required = false } },
          { approle_secret_id = { type = "string", required = false, encrypted = true, referenceable = true } },
          { approle_secret_id_file = { type = "string", required = false } },

          -- Kubernetes auth
          { kube_role = { type = "string", required = false } },
          { kube_auth_path = { type = "string", default = "kubernetes" } },
          { kube_api_token_file = {
              type = "string",
              required = false,
              default = "/run/secrets/kubernetes.io/serviceaccount/token",
          } },

          { cacheable_methods = {
              type = "array",
              elements = { type = "string", one_of = { "GET", "LIST", "HEAD" } },
              default = { "GET" },
          } },
          { cache = {
              type = "record",
              fields = {
                { enabled = { type = "boolean", required = true, default = true } },
                { kv_min_cache_ttl = { type = "number", required = true, default = 30, gt = 0 } },
                { default_ttl = { type = "number", required = true, default = 300, gt = 0 } },
                { neg_ttl = { type = "number", required = true, default = 5, gt = 0 } },
              },
          } },
        },
        custom_validator = validate_config,
        entity_checks = {
          {
            conditional = {
              if_field = "auth_method", if_match = { eq = "token" },
              then_field = "token", then_match = { required = true },
            },
          },
          {
            conditional = {
              if_field = "auth_method", if_match = { eq = "approle" },
              then_field = "approle_role_id", then_match = { required = true },
            },
          },
          {
            conditional = {
              if_field = "auth_method", if_match = { eq = "kubernetes" },
              then_field = "kube_role", then_match = { required = true },
            },
          },
        },
    } },
  },
}
