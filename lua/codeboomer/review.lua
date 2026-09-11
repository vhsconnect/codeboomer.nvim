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
local function with_agent_user()
  local entry_3f = sqlite.user:get({where = {email = "agent@codeboomer"}})
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
    return sqlite.user:insert({name = "agent", email = "agent@codeboomer"})
  end
end
local function with_repo()
  local repo_path = git["repo-root"]()
  local entry_3f = sqlite.repo:get({where = {path = repo_path}})
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
    return sqlite.repo:insert({path = repo_path})
  end
end
local function with_commit(repo_id)
  local commit_hash = git["head-sha"]()
  local entry_3f = sqlite.commit:get({where = {hash = commit_hash}})
  if entry_3f[1] then
    local t_13_ = entry_3f
    if (nil ~= t_13_) then
      t_13_ = t_13_[1]
    else
    end
    if (nil ~= t_13_) then
      t_13_ = t_13_.id
    else
    end
    return t_13_
  else
    return sqlite.commit:insert({hash = commit_hash, repo = repo_id})
  end
end
M["user-comment"] = function(session_id, file_path, line_start, line_end, code, body)
  local user_id = with_user()
  local repo_id = with_repo()
  local commit_id = with_commit(repo_id)
  local thread_id = sqlite.thread:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = code, anchor_commit = commit_id, status = "open", created_by = user_id})
  return sqlite.comments:insert({thread_id = thread_id, author_id = user_id, body = body, source = "user", commit_id = commit_id})
end
M["get-sessions"] = function()
  return sqlite.session:get({where = {repo_id = with_repo()}})
end
M["agent-reply"] = function(thread_id, body)
  local rows = (sqlite.thread:get({where = {id = thread_id}}) or {})
  local thread = rows[1]
  if (not thread or thread.deleted_at) then
    vim.notify(("codeboomer: no active thread #" .. tostring(thread_id)), vim.log.levels.ERROR)
    return nil
  elseif ("" == (body or "")) then
    vim.notify("codeboomer: empty reply body", vim.log.levels.ERROR)
    return nil
  else
    return sqlite.comments:insert({thread_id = thread_id, author_id = with_agent_user(), body = body, source = "agent", commit_id = thread.anchor_commit})
  end
end
M["active-session-id"] = function()
  local root = git["repo-root"]()
  if root then
    local repo_id
    do
      local t_18_ = sqlite.repo:get({where = {path = root}})
      if (nil ~= t_18_) then
        t_18_ = t_18_[1]
      else
      end
      if (nil ~= t_18_) then
        t_18_ = t_18_.id
      else
      end
      repo_id = t_18_
    end
    if repo_id then
      local sessions = (sqlite.session:get({where = {repo_id = repo_id}}) or {})
      local case_21_ = #sessions
      if (case_21_ == 0) then
        return nil
      elseif (case_21_ == 1) then
        local t_22_ = sessions
        if (nil ~= t_22_) then
          t_22_ = t_22_[1]
        else
        end
        if (nil ~= t_22_) then
          t_22_ = t_22_.id
        else
        end
        return t_22_
      else
        local _ = case_21_
        return error("Multiple session not implemented")
      end
    else
      return nil
    end
  else
    return nil
  end
end
M["commit-sha"] = function(commit_id)
  local t_28_ = sqlite.commit:get({where = {id = commit_id}})
  if (nil ~= t_28_) then
    t_28_ = t_28_[1]
  else
  end
  if (nil ~= t_28_) then
    t_28_ = t_28_.hash
  else
  end
  return t_28_
end
M["pending-annotations"] = function(session_id, flag)
  if not session_id then
    return {}
  else
    local me = with_user()
    local out = {}
    for _, t in ipairs(M["threads-for-session"](session_id)) do
      for _0, c in ipairs(M["comments-for"]((t.id or 0))) do
        if (((c.author_id or 0) == me) and ((c.source or "user") == "user") and (0 == (c[flag] or 0)) and ("" ~= (c.body or ""))) then
          table.insert(out, {thread = t, comment = c})
        else
        end
      end
    end
    return out
  end
end
M["mark-annotations"] = function(flag, ids)
  if vim.tbl_contains({"sent", "posted"}, flag) then
    local function _33_(d)
      for _, id in ipairs(ids) do
        d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
      end
      return nil
    end
    return sqlite.db:with_open(_33_)
  else
    return nil
  end
end
M["threads-for"] = function(session_id, file_path)
  local rows = sqlite["active-rows"]((sqlite.thread:get({where = {session_id = session_id, file_path = file_path}}) or {}))
  local function _35_(a, b)
    return ((a.line_start or 0) < (b.line_start or 0))
  end
  table.sort(rows, _35_)
  return rows
end
M["threads-for-session"] = function(session_id)
  local rows = sqlite["active-rows"]((sqlite.thread:get({where = {session_id = session_id}}) or {}))
  local function _36_(a, b)
    local pa = (a.file_path or "")
    local pb = (b.file_path or "")
    if (pa == pb) then
      return ((a.line_start or 0) < (b.line_start or 0))
    else
      return (pa < pb)
    end
  end
  table.sort(rows, _36_)
  return rows
end
M["comments-for"] = function(thread_id)
  local rows = sqlite["active-rows"]((sqlite.comments:get({where = {thread_id = thread_id}}) or {}))
  local function _38_(a, b)
    local ta = (a.created_at or 0)
    local tb = (b.created_at or 0)
    if (ta == tb) then
      return ((a.id or 0) < (b.id or 0))
    else
      return (ta < tb)
    end
  end
  table.sort(rows, _38_)
  return rows
end
M["create-session"] = function()
  local repo_id = with_repo()
  return sqlite.session:insert({name = "session1", branch = git["branch-name"](), head_commit = with_commit(repo_id), repo_id = repo_id})
end
return M
