-- [nfnl] compis/config.fnl
vim = vim
local defaults = {provider = "ollama", openai = {endpoint = "https://api.openai.com/v1", model = "gpt-4o", timeout = 30000, temperature = 0, max_tokens = 4096}, copilot = {endpoint = "https://api.githubcopilot.com", model = "gpt-4o-2024-05-13", timeout = 30000, temperature = 0, max_tokens = 4096}, azure = {endpoint = "", deployment = "", api_version = "2024-06-01", timeout = 30000, temperature = 0, max_tokens = 4096}, claude = {endpoint = "https://api.anthropic.com", model = "claude-3-5-sonnet-20240620", timeout = 30000, temperature = 0, max_tokens = 8000}, gemini = {endpoint = "https://generativelanguage.googleapis.com/v1beta/models", model = "gemini-1.5-flash-latest", timeout = 30000, temperature = 0, max_tokens = 4096}, cohere = {endpoint = "https://api.cohere.com/v1", model = "command-r-plus-08-2024", timeout = 30000, temperature = 0, max_tokens = 4096}, openrouter = {endpoint = "https://openrouter.ai/api/v1", model = "deepseek/deepseek-v3.2", timeout = 30000, temperature = 0, max_tokens = 4096}, ollama = {endpoint = "http://localhost:11434", model = "nemotron-mini:latest", timeout = 30000, temperature = 0, max_tokens = 4096}}
local M = {config = defaults}
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", defaults, (opts or {}))
  return nil
end
M.get_provider = function(name)
  return vim.deepcopy(M.config[(name or M.config.provider)], true)
end
return M
