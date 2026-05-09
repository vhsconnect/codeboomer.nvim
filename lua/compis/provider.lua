-- [nfnl] compis/provider.fnl
vim = vim
local config = require("compis.config")
local curl = require("plenary.curl")
local function get_api_key(provider_name)
  local env_var
  if (provider_name == "openrouter") then
    env_var = "OPENROUTER_API_KEY"
  elseif (provider_name == "openai") then
    env_var = "OPENAI_API_KEY"
  elseif (provider_name == "claude") then
    env_var = "ANTHROPIC_API_KEY"
  else
    env_var = nil
  end
  if env_var then
    return os.getenv(env_var)
  else
    return nil
  end
end
local function build_messages(system_prompt, user_prompt)
  return {{role = "system", content = system_prompt}, {role = "user", content = user_prompt}}
end
local function build_curl_args(provider_name, messages)
  local provider = config.get_provider(provider_name)
  local api_key = get_api_key(provider_name)
  local endpoint = provider.endpoint:gsub("/+$", "")
  local url = (endpoint .. "/chat/completions")
  local headers = {["Content-Type"] = "application/json"}
  local headers0
  if api_key then
    headers0 = vim.tbl_deep_extend("force", headers, {Authorization = ("Bearer " .. api_key)})
  else
    headers0 = headers
  end
  local body = vim.json.encode({model = provider.model, messages = messages, temperature = (provider.temperature or 0), max_tokens = (provider.max_tokens or 4096), stream = false})
  return {url = url, headers = headers0, body = body}
end
local function complete(system_prompt, user_prompt, callback)
  local provider_name = config.config.provider
  local api_key = get_api_key(provider_name)
  if not api_key then
    return callback(nil, ("compis: API key not found for provider " .. provider_name))
  else
    local messages = build_messages(system_prompt, user_prompt)
    local args = build_curl_args(provider_name, messages)
    local function _4_(res)
      if (res.status ~= 200) then
        return callback(nil, ("compis: request failed \226\128\147 HTTP " .. res.status .. " \226\128\147 " .. res.body))
      else
        local ok, parsed = pcall(vim.json.decode, res.body)
        if not ok then
          return callback(nil, ("compis: failed to parse response \226\128\147 " .. parsed))
        else
          return callback(parsed, nil)
        end
      end
    end
    return curl.post(args.url, {headers = args.headers, body = args.body, callback = _4_})
  end
end
return {complete = complete, ["get-api-key"] = get_api_key, ["build-messages"] = build_messages, ["build-curl-args"] = build_curl_args}
