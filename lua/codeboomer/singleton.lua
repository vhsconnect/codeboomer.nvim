-- [nfnl] fnl/codeboomer/singleton.fnl
vim = vim
local sqlite = require("sqlite")
local db = nil
local M
local function get_db()
  if (db == nil) then
    db = sqlite({uri = (vim.fn.stdpath("data") .. "/codeboomer"), opts = {journal_mode = "WAL", synchronous = "NORMAL", busy_timeout = 500, foreign_keys = "ON", auto_vacuum = "INCREMENTAL", wal_autocheckpoint = 100}})
    return db
  else
    local _ = db
    return db
  end
end
M = {["get-db"] = get_db}
return M
