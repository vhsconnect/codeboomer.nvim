-- [nfnl] fnl/codeboomer/sqlite.fnl
vim = vim
local function assert_valid_status(status)
  return assert(((status == "open") or (status == "resolved")), ("invalid thread status: " .. tostring(status)))
end
local created_at_default = "strftime('%s', 'now')"
local id_column = {"integer", "primary", "key", "autoincrement"}
local user_schema = {id = id_column, name = "text", email = {type = "text", required = true, unique = true}}
local repo_schema = {id = id_column, path = {type = "text", unique = true}}
local commit_schema = {id = id_column, hash = {type = "text", required = true, unique = true}, repo = {type = "integer", reference = "repo.id", on_delete = "cascade"}}
local session_schema = {id = id_column, branch = "text", pr_number = "integer", repo_id = {type = "integer", reference = "repo.id", on_delete = "cascade"}}
local thread_schema = {id = id_column, session_id = {type = "integer", reference = "session.id", on_delete = "cascade"}, file_path = {type = "text", required = true}, line_start = "integer", line_end = "integer", code_snapshot = "text", anchor_commit = {type = "integer", reference = "git_commit.id", on_delete = "cascade"}, status = {type = "text", required = true}, kind = "text", type = {type = "text", default = "'line'"}, parent_id = {type = "integer", reference = "comment_thread.id", on_delete = "null"}, gh_outdated = "integer", gh_line = "integer", gh_original_line = "integer", gh_original_commit = {type = "integer", reference = "git_commit.id", on_delete = "null"}, created_by = {type = "integer", reference = "user.id", on_delete = "cascade"}, created_at = {type = "integer", default = created_at_default}}
local comment_schema = {id = id_column, thread_id = {type = "integer", reference = "comment_thread.id", on_delete = "cascade"}, body = {type = "text", required = true}, commit_id = {type = "integer", reference = "git_commit.id", on_delete = "cascade"}, author_id = {type = "integer", reference = "user.id", on_delete = "cascade"}, source = "text", gh_comment_id = {type = "text", unique = true}, sent = {type = "integer", default = 0}, posted = {type = "integer", default = 0}, created_at = {type = "integer", default = created_at_default}}
local tbl_cache = {}
local function tbl_for(name, schema, db)
  local per_db
  local or_1_ = tbl_cache[db]
  if not or_1_ then
    local fresh = {}
    tbl_cache[db] = fresh
    or_1_ = fresh
  end
  per_db = or_1_
  local or_3_ = per_db[name]
  if not or_3_ then
    local wrapper = require("sqlite.tbl")(name, schema, db)
    per_db[name] = wrapper
    or_3_ = wrapper
  end
  return or_3_
end
local user
local function _5_(db)
  return tbl_for("user", user_schema, db)
end
user = _5_
local repo
local function _6_(db)
  return tbl_for("repo", repo_schema, db)
end
repo = _6_
local session
local function _7_(db)
  return tbl_for("session", session_schema, db)
end
session = _7_
local commit
local function _8_(db)
  return tbl_for("git_commit", commit_schema, db)
end
commit = _8_
local thread
local function _9_(db)
  return tbl_for("comment_thread", thread_schema, db)
end
thread = _9_
local comments
local function _10_(db)
  return tbl_for("comment", comment_schema, db)
end
comments = _10_
local M = {user = user, repo = repo, session = session, commit = commit, thread = thread, comments = comments, ["assert-valid-status"] = assert_valid_status}
return M
