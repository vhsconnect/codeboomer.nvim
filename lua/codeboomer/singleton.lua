-- [nfnl] fnl/codeboomer/singleton.fnl
vim = vim
local db = nil
local migrated = nil
local function migrate()
  if (not migrated and db) then
    migrated = true
    local function _1_(d)
      local rows
      local function _2_(sql)
        local res = d:eval(sql)
        if ("table" == type(res)) then
          return res
        else
          return {}
        end
      end
      rows = _2_
      local has_table
      do
        local t_4_ = rows("select 1 as one from sqlite_master\n                                    where type = 'table'\n                                      and name = 'comment_thread'")
        if (nil ~= t_4_) then
          t_4_ = t_4_[1]
        else
        end
        if (nil ~= t_4_) then
          t_4_ = t_4_.one
        else
        end
        has_table = t_4_
      end
      local has_type
      do
        local t_7_ = rows("select 1 as one from pragma_table_info('comment_thread')\n                                   where name = 'type'")
        if (nil ~= t_7_) then
          t_7_ = t_7_[1]
        else
        end
        if (nil ~= t_7_) then
          t_7_ = t_7_.one
        else
        end
        has_type = t_7_
      end
      if (has_table and not has_type) then
        return d:execute("alter table comment_thread add column type text default 'line'")
      else
        return nil
      end
    end
    return db:with_open(_1_)
  else
    return nil
  end
end
local function force_close()
  if db then
    local function _12_()
      if db:isopen() then
        return db:close()
      else
        return nil
      end
    end
    pcall(_12_)
    if (db and db:isopen()) then
      local function _14_()
        return require("sqlite.defs").close_v2(db.conn)
      end
      pcall(_14_)
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
    migrate()
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
local function _18_()
  return M["close-db"]()
end
vim.api.nvim_create_autocmd("VimLeavePre", {callback = _18_})
return M
