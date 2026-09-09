-- [nfnl] fnl/codeboomer/review.fnl
vim = vim
local git = require("codeboomer.git")
local sqlite = require("codeboomer.sqlite")
local M = {}
local function with_user()
  local email = git["user-email"]()
  local entry_3f = sqlite.user:get({where = {email = email}})
  if entry_3f[1] then
    local t_1_ = entry_3f
    if (nil ~= t_1_) then
      t_1_ = t_1_[1]
    else
    end
    if (nil ~= t_1_) then
      t_1_ = t_1_.id
    else
    end
    return t_1_
  else
    return sqlite.user:insert({name = git["user-name"](), email = email})
  end
end
local function with_repo()
  local repo_path = git["repo-root"]()
  local entry_3f = sqlite.repo:get({where = {path = repo_path}})
  if entry_3f[1] then
    local t_5_ = entry_3f
    if (nil ~= t_5_) then
      t_5_ = t_5_[1]
    else
    end
    if (nil ~= t_5_) then
      t_5_ = t_5_.id
    else
    end
    return t_5_
  else
    return sqlite.repo:insert({path = repo_path})
  end
end
local function with_commit(repo_id)
  local commit_hash = git["head-sha"]()
  local entry_3f = sqlite.commit:get({where = {hash = commit_hash}})
  if entry_3f[1] then
    local t_9_ = entry_3f
    if (nil ~= t_9_) then
      t_9_ = t_9_[1]
    else
    end
    if (nil ~= t_9_) then
      t_9_ = t_9_.id
    else
    end
    return t_9_
  else
    return sqlite.commit:insert({hash = commit_hash, repo = repo_id})
  end
end
local function prn_debug(x)
  print(x)
  return x
end
M["user-comment"] = function(session_id, file_path, line_start, line_end, code, body)
  local user_id = with_user()
  local repo_id = with_repo()
  local commit_id = with_commit(repo_id)
  local thread_id = sqlite.thread:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = code, anchor_commit = commit_id, status = "open", created_by = user_id})
  return sqlite.comments:insert({thread_id = thread_id, author_id = prn_debug(user_id), body = body, commit_id = commit_id})
end
M["get-sessions"] = function()
  return sqlite.session:get({where = {repo_id = with_repo()}})
end
M["active-session-id"] = function()
  local sessions = (M["get-sessions"]() or {})
  local case_13_ = #sessions
  if (case_13_ == 0) then
    return nil
  elseif (case_13_ == 1) then
    local t_14_ = sessions
    if (nil ~= t_14_) then
      t_14_ = t_14_[1]
    else
    end
    if (nil ~= t_14_) then
      t_14_ = t_14_.id
    else
    end
    return t_14_
  else
    local _ = case_13_
    return error("Multiple session not implemented")
  end
end
M["threads-for"] = function(session_id, file_path)
  local rows = sqlite["active-rows"]((sqlite.thread:get({where = {session_id = session_id, file_path = file_path}}) or {}))
  local function _18_(a, b)
    return ((a.line_start or 0) < (b.line_start or 0))
  end
  table.sort(rows, _18_)
  return rows
end
M["comments-for"] = function(thread_id)
  local rows = sqlite["active-rows"]((sqlite.comments:get({where = {thread_id = thread_id}}) or {}))
  local function _19_(a, b)
    local ta = (a.created_at or 0)
    local tb = (b.created_at or 0)
    if (ta == tb) then
      return ((a.id or 0) < (b.id or 0))
    else
      return (ta < tb)
    end
  end
  table.sort(rows, _19_)
  return rows
end
M["create-session"] = function()
  local repo_id = with_repo()
  return sqlite.session:insert({name = "session1", branch = git["branch-name"](), head_commit = with_commit(repo_id), repo_id = repo_id})
end
return M
