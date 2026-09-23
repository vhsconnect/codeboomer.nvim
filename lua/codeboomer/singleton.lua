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
local function close_db()
  local function _2_()
    if (db and db:isopen()) then
      return db:close()
    else
      return nil
    end
  end
  pcall(_2_)
  db = nil
  return nil
end
local function reset_db()
  db = nil
  return nil
end
M = {["get-db"] = get_db, ["close-db"] = close_db, ["reset-db"] = reset_db}
local function _4_()
  return M["close-db"]()
end
vim.api.nvim_create_autocmd("VimLeavePre", {callback = _4_})
return M
