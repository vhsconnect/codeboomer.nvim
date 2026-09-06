-- [nfnl] codeboomer/sqlite.fnl
vim = vim
local sqlite = require("sqlite")
local tbl = require("sqlite.tbl")
local db = sqlite({uri = "/home/vhs/.local/share/nvim/codeboomer", opts = {journal_mode = "WAL", synchronous = "NORMAL", busy_timeout = 500, foreign_keys = "ON", auto_vacuum = "INCREMENTAL"}})
local function assert_valid_status(status)
  return assert(((status == "open") or (status == "resolved")), ("invalid thread status: " .. tostring(status)))
end
local user_schema = {id = true, name = "text", email = {type = "text", required = true, unique = true}}
local repo_schema = {id = true, path = {type = "text", unique = true}, name = "text"}
local branch_schema = {id = true, name = "text", head_commit_sha = "text", repo_id = {type = "integer", reference = "repo.id", on_delete = "cascade"}}
local thread_schema = {id = true, branch_id = {type = "integer", reference = "branch.id", on_delete = "cascade"}, file_path = "text", line_start = "integer", line_end = "integer", code_snapshot = "text", anchor_commit_sha = "text", status = {type = "text", required = true}, created_by = {type = "integer", reference = "user.id", on_delete = "cascade"}, created_at = {type = "integer", default = sqlite.lib.strftime("%s", "now")}, deleted_at = "integer"}
local comment_schema = {id = true, thread_id = {type = "integer", reference = "comment_thread.id", on_delete = "cascade"}, body = "text", author_id = {type = "integer", reference = "user.id", on_delete = "cascade"}, created_at = {type = "integer", default = sqlite.lib.strftime("%s", "now")}, deleted_at = "integer"}
local user = tbl("user", user_schema, db)
local repo = tbl("repo", repo_schema, db)
local branch = tbl("branch", branch_schema, db)
local threads = tbl("comment_thread", thread_schema, db)
local comments = tbl("comment", comment_schema, db)
local function active_rows(rows)
  local out = {}
  for _, row in ipairs(rows) do
    if (row.deleted_at == nil) then
      table.insert(out, row)
    else
    end
  end
  return out
end
local M = {db = db, user = user, repo = repo, branch = branch, threads = threads, comments = comments, ["assert-valid-status"] = assert_valid_status, ["active-rows"] = active_rows}
return M
