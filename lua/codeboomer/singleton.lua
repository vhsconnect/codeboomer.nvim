-- [nfnl] fnl/codeboomer/singleton.fnl
vim = vim
local db = nil
local function force_close()
  if db then
    local function _1_()
      if db:isopen() then
        return db:close()
      else
        return nil
      end
    end
    pcall(_1_)
    if (db and db:isopen()) then
      local function _3_()
        return require("sqlite.defs").close_v2(db.conn)
      end
      pcall(_3_)
    else
    end
    db = nil
    return nil
  else
    return nil
  end
end
local M
local function get_db()
  if (db == nil) then
    local sqlite = require("sqlite")
    db = sqlite({uri = (vim.fn.stdpath("data") .. "/codeboomer"), opts = {journal_mode = "WAL", synchronous = "NORMAL", busy_timeout = 500, foreign_keys = "ON", auto_vacuum = "INCREMENTAL", wal_autocheckpoint = 100}})
    return db
  else
    local _ = db
    return db
  end
end
local function close_db()
  return force_close()
end
local function reset_db()
  return force_close()
end
M = {["get-db"] = get_db, ["close-db"] = close_db, ["reset-db"] = reset_db}
local function _7_()
  return M["close-db"]()
end
vim.api.nvim_create_autocmd("VimLeavePre", {callback = _7_})
return M
