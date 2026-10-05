-- [nfnl] fnl/codeboomer/singleton.fnl
vim = vim
local db = nil
local db_version = 1
local function db_path()
  return string.format("%s/codeboomer-db-v%d", vim.fn.stdpath("data"), db_version)
end
local schema_ready = nil
local function ensure_schema()
  if (not schema_ready and db) then
    schema_ready = true
    do
      local sqlite = require("codeboomer.sqlite")
      for _, tbl in ipairs({sqlite.user, sqlite.repo, sqlite.commit, sqlite.session, sqlite.thread, sqlite.comments}) do
        tbl(db)
      end
    end
    local function _1_(d)
      return d:execute("create unique index if not exists session_branch\n                    on session (repo_id, branch)")
    end
    return db:with_open(_1_)
  else
    return nil
  end
end
local function force_close()
  if db then
    local function _3_()
      if db:isopen() then
        return db:close()
      else
        return nil
      end
    end
    pcall(_3_)
    if (db and db:isopen()) then
      local function _5_()
        return require("sqlite.defs").close_v2(db.conn)
      end
      pcall(_5_)
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
    db = sqlite({uri = db_path(), opts = {journal_mode = "WAL", synchronous = "NORMAL", busy_timeout = 500, foreign_keys = "ON", auto_vacuum = "INCREMENTAL", wal_autocheckpoint = 100}})
    ensure_schema()
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
M = {["get-db"] = get_db, ["close-db"] = close_db, ["reset-db"] = reset_db, ["db-path"] = db_path}
local function _9_()
  return M["close-db"]()
end
vim.api.nvim_create_autocmd("VimLeavePre", {callback = _9_})
return M
