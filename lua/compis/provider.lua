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
local function is_ollama_3f(provider_name)
  return (provider_name == "ollama")
end
local function build_openai_args(provider_name, messages)
  local provider = config.get_provider(provider_name)
  local api_key = get_api_key(provider_name)
  local endpoint = provider.endpoint:gsub("/+$", "")
  local url = (endpoint .. "/chat/completions")
  local headers = {["Content-Type"] = "application/json", Authorization = ("Bearer " .. api_key)}
  local body = vim.json.encode({model = provider.model, messages = messages, temperature = (provider.temperature or 0), max_tokens = (provider.max_tokens or 4096), stream = false})
  return {url = url, headers = headers, body = body}
end
local function build_ollama_args(provider_name, system_prompt, user_prompt)
  local provider = config.get_provider(provider_name)
  local endpoint = provider.endpoint:gsub("/+$", "")
  local url = (endpoint .. "/api/generate")
  local headers = {["Content-Type"] = "application/json"}
  local body = vim.json.encode({model = provider.model, prompt = ((system_prompt or "") .. "\n\n" .. user_prompt), temperature = (provider.temperature or 0), stream = false})
  return {url = url, headers = headers, body = body}
end
local function build_curl_args(provider_name, messages, system_prompt, user_prompt)
  if is_ollama_3f(provider_name) then
    return build_ollama_args(provider_name, system_prompt, user_prompt)
  else
    return build_openai_args(provider_name, messages)
  end
end
local function extract_content(provider_name, data)
  if is_ollama_3f(provider_name) then
    local t_4_ = data
    if (nil ~= t_4_) then
      t_4_ = t_4_.response
    else
    end
    return t_4_
  else
    local t_6_ = data
    if (nil ~= t_6_) then
      t_6_ = t_6_.choices
    else
    end
    if (nil ~= t_6_) then
      t_6_ = t_6_[1]
    else
    end
    if (nil ~= t_6_) then
      t_6_ = t_6_.message
    else
    end
    if (nil ~= t_6_) then
      t_6_ = t_6_.content
    else
    end
    return t_6_
  end
end
local function complete(system_prompt, user_prompt, callback)
  local provider_name = config.config.provider
  local api_key = get_api_key(provider_name)
  local ollama_3f = is_ollama_3f(provider_name)
  if (not api_key and not ollama_3f) then
    return callback(nil, ("compis: API key not found for provider " .. provider_name))
  else
    local messages = build_messages(system_prompt, user_prompt)
    local args = build_curl_args(provider_name, messages, system_prompt, user_prompt)
    local function _12_(res)
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
    return curl.post(args.url, {headers = args.headers, body = args.body, callback = _12_})
  end
end
return {complete = complete, ["get-api-key"] = get_api_key, ["build-messages"] = build_messages, ["build-curl-args"] = build_curl_args, ["extract-content"] = extract_content}
