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
local function with_commit(repo_id, _3fsha)
  local commit_hash = (_3fsha or git["head-sha"]())
  if commit_hash then
    local entry_3f = sqlite.commit:get({where = {hash = commit_hash}})
    local _14_
    do
      local t_13_ = entry_3f
      if (nil ~= t_13_) then
        t_13_ = t_13_[1]
      else
      end
      if (nil ~= t_13_) then
        t_13_ = t_13_.id
      else
      end
      _14_ = t_13_
    end
    if _14_ then
      local t_17_ = entry_3f
      if (nil ~= t_17_) then
        t_17_ = t_17_[1]
      else
      end
      if (nil ~= t_17_) then
        t_17_ = t_17_.id
      else
      end
      return t_17_
    else
      return sqlite.commit:insert({hash = commit_hash, repo = repo_id})
    end
  else
    return nil
  end
end
M["user-comment"] = function(session_id, file_path, line_start, line_end, code, body)
  local user_id = with_user()
  local repo_id = with_repo()
  local commit_id = with_commit(repo_id)
  local thread_id = sqlite.thread:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = code, anchor_commit = commit_id, status = "open", created_by = user_id})
  return sqlite.comments:insert({thread_id = thread_id, author_id = user_id, body = body, source = "user", commit_id = commit_id})
end
local current_session_id = nil
M["current-session-id"] = function()
  return current_session_id
end
M["set-session"] = function(id, _3fsilent)
  current_session_id = id
  if not _3fsilent then
    return vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerSessionChanged"})
  else
    return nil
  end
end
M["existing-sessions"] = function()
  local root = git["repo-root"]()
  if root then
    local repo_id
    do
      local t_23_ = sqlite.repo:get({where = {path = root}})
      if (nil ~= t_23_) then
        t_23_ = t_23_[1]
      else
      end
      if (nil ~= t_23_) then
        t_23_ = t_23_.id
      else
      end
      repo_id = t_23_
    end
    if repo_id then
      local sessions = (sqlite.session:get({where = {repo_id = repo_id}}) or {})
      local function _26_(a, b)
        return ((a.id or 0) < (b.id or 0))
      end
      table.sort(sessions, _26_)
      return sessions
    else
      return nil
    end
  else
    return nil
  end
end
M["adopt-sole-session"] = function()
  local sessions = (M["existing-sessions"]() or {})
  if (1 == #sessions) then
    local _30_
    do
      local t_29_ = sessions
      if (nil ~= t_29_) then
        t_29_ = t_29_[1]
      else
      end
      if (nil ~= t_29_) then
        t_29_ = t_29_.id
      else
      end
      _30_ = t_29_
    end
    return M["set-session"](_30_, true)
  else
    return nil
  end
end
M["agent-reply"] = function(thread_id, body)
  local rows = (sqlite.thread:get({where = {id = thread_id}}) or {})
  local thread = rows[1]
  if (not thread or thread.deleted_at or (thread.status == "resolved")) then
    vim.notify(("codeboomer: no active thread #" .. tostring(thread_id)), vim.log.levels.ERROR)
    return nil
  elseif ("" == (body or "")) then
    vim.notify("codeboomer: empty reply body", vim.log.levels.ERROR)
    return nil
  else
    return sqlite.comments:insert({thread_id = thread_id, author_id = with_agent_user(), body = body, source = "agent", commit_id = thread.anchor_commit})
  end
end
M["user-reply"] = function(thread_id, body)
  local rows = (sqlite.thread:get({where = {id = thread_id}}) or {})
  local thread = rows[1]
  if (not thread or thread.deleted_at or (thread.status == "resolved")) then
    vim.notify(("codeboomer: no active thread #" .. tostring(thread_id)), vim.log.levels.ERROR)
    return nil
  elseif ("" == (body or "")) then
    vim.notify("codeboomer: empty reply body", vim.log.levels.ERROR)
    return nil
  else
    return sqlite.comments:insert({thread_id = thread_id, author_id = with_user(), body = body, source = "user", commit_id = thread.anchor_commit})
  end
end
M["resolve-thread"] = function(thread_id)
  return sqlite.thread:update({set = {status = "resolved"}, where = {id = thread_id}})
end
M["commit-sha"] = function(commit_id)
  local t_36_ = sqlite.commit:get({where = {id = commit_id}})
  if (nil ~= t_36_) then
    t_36_ = t_36_[1]
  else
  end
  if (nil ~= t_36_) then
    t_36_ = t_36_.hash
  else
  end
  return t_36_
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
    local function _41_(d)
      for _, id in ipairs(ids) do
        d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
      end
      return nil
    end
    return sqlite.db:with_open(_41_)
  else
    return nil
  end
end
local function unresolved_rows(rows)
  local out = {}
  for _, row in ipairs(rows) do
    if (row.status ~= "resolved") then
      table.insert(out, row)
    else
    end
  end
  return out
end
M["threads-for-session"] = function(session_id)
  local rows = unresolved_rows(sqlite["active-rows"]((sqlite.thread:get({where = {session_id = session_id}}) or {})))
  local function _44_(a, b)
    local pa = (a.file_path or "")
    local pb = (b.file_path or "")
    if (pa == pb) then
      return ((a.line_start or 0) < (b.line_start or 0))
    else
      return (pa < pb)
    end
  end
  table.sort(rows, _44_)
  return rows
end
M["comments-for"] = function(thread_id)
  local rows = sqlite["active-rows"]((sqlite.comments:get({where = {thread_id = thread_id}}) or {}))
  local function _46_(a, b)
    local ta = (a.created_at or 0)
    local tb = (b.created_at or 0)
    if (ta == tb) then
      return ((a.id or 0) < (b.id or 0))
    else
      return (ta < tb)
    end
  end
  table.sort(rows, _46_)
  return rows
end
M["create-session"] = function(_3fopts)
  local opts = (_3fopts or {})
  local repo_id = with_repo()
  local function _49_()
    local t_48_ = opts
    if (nil ~= t_48_) then
      t_48_ = t_48_["head-sha"]
    else
    end
    return t_48_
  end
  local function _52_()
    local t_51_ = opts
    if (nil ~= t_51_) then
      t_51_ = t_51_["base-sha"]
    else
    end
    return t_51_
  end
  return sqlite.session:insert({branch = (opts.branch or git["branch-name"]()), head_commit = with_commit(repo_id, _49_()), base_commit = with_commit(repo_id, _52_()), repo_id = repo_id, pr_number = opts["pr-number"]})
end
return M
