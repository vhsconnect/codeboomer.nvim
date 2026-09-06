-- [nfnl] codeboomer/sqlite.fnl
vim = vim
local sqlite = require("sqlite")
local tbl = require("sqlite.tbl")
local db = sqlite({uri = "/home/vhs/.local/share/nvim/codeboomer", opts = {journal_mode = "WAL", synchronous = "NORMAL", busy_timeout = 500, foreign_keys = "ON", auto_vacuum = "INCREMENTAL"}})
local user_schema = {id = true, name = "text", email = "text"}
local repo_schema = {id = true, path = "text", name = "text"}
local branch_schema = {id = true, name = "text", head_commit_sha = "text", repo_id = {type = "integer", reference = "repo.id", on_delete = "cascade"}}
local comment_thread_schema = {id = true, repo_id = {type = "integer", reference = "repo.id", on_delete = "cascade"}, branch_id = {type = "integer", reference = "branch.id", on_delete = "cascade"}, file_path = "text", line_start = "integer", line_end = "integer", code_snapshot = "text", anchor_commit_sha = "text", status = "text", created_by = {type = "integer", reference = "user.id", on_delete = "cascade"}, created_at = {type = "date", default = sqlite.lib.strftime("%s", "now")}, deleted_at = "date"}
local comment_schema = {id = true, thread_id = {type = "integer", reference = "comment_thread.id", on_delete = "cascade"}, body = "text", author_id = {type = "integer", reference = "user.id", on_delete = "cascade"}, created_at = {type = "date", default = sqlite.lib.strftime("%s", "now")}, created_by = {type = "integer", reference = "user.id", on_delete = "cascade"}, deleted_at = "date"}
local user = tbl("user", user_schema, db)
local repo = tbl("repo", repo_schema, db)
local branch = tbl("branch", branch_schema, db)
local comments_thread = tbl("comment_thread", comment_thread_schema, db)
local comments = tbl("comment", comment_schema, db)
branch:remove()
repo:where({id = 1})
branch:get({where = {repo = 1}})
comments:count()
local function _1_(row)
  return print(row.content)
end
comments:each(_1_)
local function _2_(row)
  return print(row.content)
end
return comments:each(_2_)
