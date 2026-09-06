-- [nfnl] codeboomer/review.fnl
vim = vim
local git = require("codeboomer.git")
local sqlite = require("codeboomer.sqlite")
local M = {}
local function with_user()
  local email = git["user-email"]()
  local entry_3f = sqlite.user:get({where = {email = email}})
  if entry_3f then
    return entry_3f.id
  else
    return sqlite.user:insert({name = git["user-name"](), email = email})
  end
end
local function with_repo()
  local repo_path = git["repo-root"]()
  local entry_3f = sqlite.repo:get({where = {path = repo_path}})
  if entry_3f then
    return entry_3f.id
  else
    return sqlite.repo:insert({path = repo_path})
  end
end
local function with_commit(repo_id)
  local commit_hash = git["head-sha"]()
  local entry_3f = sqlite.commit:get({where = {hash = commit_hash}})
  if entry_3f then
    return entry_3f.id
  else
    return sqlite.commit:insert({hash = commit_hash, repo = repo_id})
  end
end
M["user-comment"] = function(session_id, file_path, line_start, line_end, code, body)
  local user_id = with_user()
  local repo_id = with_repo()
  local commit_id = with_commit(repo_id)
  local thread_id = sqlite.thread:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = code, anchor_commit = commit_id, status = "open", created_by = user_id})
  return sqlite.comment:insert({thread_id = thread_id, author_id = user_id, body = body, commit = commit_id})
end
return M
