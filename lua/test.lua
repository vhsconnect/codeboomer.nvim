-- [nfnl] fnl/test.fnl
local _local_1_ = require("nfnl-plugin-example.nfnl.module")
local autoload = _local_1_.autoload
local notify = autoload("nfnl-plugin-example.nfnl.notify")
local function setup()
  return notify.info("nfnl module compiled; setup() invoked")
end
vim.notify("test.fnl: exporting setup via module table", vim.log.levels.INFO)
return {setup = setup}
