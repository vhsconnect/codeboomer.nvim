-- [nfnl] compis/init.fnl
vim = vim
local config = require("compis.config")
local curl = require("plenary.curl")
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
local function _3_()
  local url = config.config.url
  local function _4_(res)
    if (res.status ~= 200) then
      return schedule_notify(("compis: request failed \226\128\147 HTTP " .. res.status), vim.log.levels.ERROR)
    else
      return schedule_notify(res.body, vim.log.levels.INFO)
    end
  end
  return curl.get(url, {callback = _4_})
end
M.ping = _3_
return M
