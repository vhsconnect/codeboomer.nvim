-- [nfnl] fnl/codeboomer/sqlite.fnl
vim = vim
local sqlite = require("sqlite")
local tbl = require("sqlite.tbl")
local function assert_valid_status(status)
  return assert(((status == "open") or (status == "resolved")), ("invalid thread status: " .. tostring(status)))
end
local user_schema = {id = true, name = "text", email = {type = "text", required = true, unique = true}}
local repo_schema = {id = true, path = {type = "text", unique = true}}
local commit_schema = {id = true, hash = {type = "text", required = true, unique = true}, repo = {type = "integer", reference = "repo.id", on_delete = "cascade"}}
local session_schema = {id = true, branch = "text", head_commit = {type = "integer", reference = "git_commit.id", on_delete = "cascade"}, base_commit = {type = "integer", reference = "git_commit.id", on_delete = "cascade"}, pr_number = "integer", repo_id = {type = "integer", reference = "repo.id", on_delete = "cascade"}}
local thread_schema = {id = true, session_id = {type = "integer", reference = "session.id", on_delete = "cascade"}, file_path = {type = "text", required = true}, line_start = "integer", line_end = "integer", code_snapshot = "text", anchor_commit = {type = "integer", reference = "git_commit.id", on_delete = "cascade"}, status = {type = "text", required = true}, gh_outdated = "integer", created_by = {type = "integer", reference = "user.id", on_delete = "cascade"}, created_at = {type = "integer", default = sqlite.lib.strftime("%s", "now")}, deleted_at = "integer"}
local comment_schema = {id = true, thread_id = {type = "integer", reference = "comment_thread.id", on_delete = "cascade"}, body = {type = "text", required = true}, commit_id = {type = "integer", reference = "git_commit.id", on_delete = "cascade"}, author_id = {type = "integer", reference = "user.id", on_delete = "cascade"}, source = "text", gh_comment_id = {type = "text", unique = true}, sent = {type = "integer", default = 0}, posted = {type = "integer", default = 0}, created_at = {type = "integer", default = sqlite.lib.strftime("%s", "now")}, deleted_at = "integer"}
local user
local function _1_(db)
  return tbl("user", user_schema, db)
end
user = _1_
local repo
local function _2_(db)
  return tbl("repo", repo_schema, db)
end
repo = _2_
local session
local function _3_(db)
  return tbl("session", session_schema, db)
end
session = _3_
local commit
local function _4_(db)
  return tbl("git_commit", commit_schema, db)
end
commit = _4_
local thread
local function _5_(db)
  return tbl("comment_thread", thread_schema, db)
end
thread = _5_
local comments
local function _6_(db)
  return tbl("comment", comment_schema, db)
end
comments = _6_
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
local M = {user = user, repo = repo, session = session, commit = commit, thread = thread, comments = comments, ["assert-valid-status"] = assert_valid_status, ["active-rows"] = active_rows}
return M
