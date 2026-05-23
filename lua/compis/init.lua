-- [nfnl] compis/init.fnl
vim = vim
local config = require("compis.config")
local provider = require("compis.provider")
local M = {}
local function _1_(opts)
  return config.setup(opts)
end
M.setup = _1_
local promise = vim.schedule
local function schedule_notify(msg, level)
  local function _2_()
    return vim.notify(msg, level)
  end
  return promise(_2_)
end
local function _3_(question)
  local system_prompt = "You are a helpful assistant. Answer concisely."
  local function _4_(result, err)
    if err then
      return schedule_notify(("compis: " .. err), vim.log.levels.ERROR)
    else
      local content = provider["extract-content"](config.config.provider, result)
      if content then
        return schedule_notify(content, vim.log.levels.INFO)
      else
        return schedule_notify("compis: no response content", vim.log.levels.WARN)
      end
    end
  end
  return provider.complete(system_prompt, question, _4_)
end
M.ask = _3_
return M
