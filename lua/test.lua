-- [nfnl] fnl/test.fnl
local _local_1_ = require("nfnl-plugin-example.nfnl.module")
local autoload = _local_1_.autoload
local notify = autoload("nfnl-plugin-example.nfnl.notify")
local function setup()
  return notify.info("Hello, World! Hi from fennel!!!! - you're too kind")
end
return {setup = setup}
