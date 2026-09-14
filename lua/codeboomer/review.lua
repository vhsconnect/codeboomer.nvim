-- [nfnl] fnl/codeboomer/review.fnl
vim = vim
local git = require("codeboomer.git")
local sqlite = require("codeboomer.sqlite")
local s = require("codeboomer.singleton")
local M = {}
local function with_user()
  local email = git["user-email"]()
  local entry_3f
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    entry_3f = t_2_auto:get({where = {email = email}})
  end
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
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    return t_2_auto:insert({name = git["user-name"](), email = email})
  end
end
local function with_agent_user()
  local entry_3f
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    entry_3f = t_2_auto:get({where = {email = "agent@codeboomer"}})
  end
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
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    return t_2_auto:insert({name = "agent", email = "agent@codeboomer"})
  end
end
local function with_repo()
  local repo_path = git["repo-root"]()
  local entry_3f
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
    entry_3f = t_2_auto:get({where = {path = repo_path}})
  end
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
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
    return t_2_auto:insert({path = repo_path})
  end
end
local function with_commit(repo_id, _3fsha)
  local commit_hash = (_3fsha or git["head-sha"]())
  if commit_hash then
    local entry_3f
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
      entry_3f = t_2_auto:get({where = {hash = commit_hash}})
    end
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
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
      return t_2_auto:insert({hash = commit_hash, repo = repo_id})
    end
  else
    return nil
  end
end
M["user-comment"] = function(session_id, file_path, line_start, line_end, code, body)
  local user_id = with_user()
  local repo_id = with_repo()
  local commit_id = with_commit(repo_id)
  local thread_id
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    thread_id = t_2_auto:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = code, anchor_commit = commit_id, status = "open", created_by = user_id})
  end
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
  return t_2_auto:insert({thread_id = thread_id, author_id = user_id, body = body, source = "user", commit_id = commit_id})
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
      local t_23_
      do
        local db_mod_1_auto = require("codeboomer.singleton")
        local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
        t_23_ = t_2_auto:get({where = {path = root}})
      end
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
      local sessions
      local _26_
      do
        local db_mod_1_auto = require("codeboomer.singleton")
        local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
        _26_ = t_2_auto:get({where = {repo_id = repo_id}})
      end
      sessions = (_26_ or {})
      local function _27_(a, b)
        return ((a.id or 0) < (b.id or 0))
      end
      table.sort(sessions, _27_)
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
    local _31_
    do
      local t_30_ = sessions
      if (nil ~= t_30_) then
        t_30_ = t_30_[1]
      else
      end
      if (nil ~= t_30_) then
        t_30_ = t_30_.id
      else
      end
      _31_ = t_30_
    end
    return M["set-session"](_31_, true)
  else
    return nil
  end
end
M["session-for-pr"] = function(pr_number)
  if pr_number then
    local root = git["repo-root"]()
    if root then
      local repo_id
      do
        local t_35_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
          t_35_ = t_2_auto:get({where = {path = root}})
        end
        if (nil ~= t_35_) then
          t_35_ = t_35_[1]
        else
        end
        if (nil ~= t_35_) then
          t_35_ = t_35_.id
        else
        end
        repo_id = t_35_
      end
      if repo_id then
        local t_38_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          t_38_ = t_2_auto:get({where = {repo_id = repo_id, pr_number = pr_number}})
        end
        if (nil ~= t_38_) then
          t_38_ = t_38_[1]
        else
        end
        return t_38_
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
M["session-by-id"] = function(id)
  if id then
    local t_43_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
      t_43_ = t_2_auto:get({where = {id = id}})
    end
    if (nil ~= t_43_) then
      t_43_ = t_43_[1]
    else
    end
    return t_43_
  else
    return nil
  end
end
M["comment-by-gh"] = function(gh_id)
  if gh_id then
    local t_46_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
      t_46_ = t_2_auto:get({where = {gh_comment_id = tostring(gh_id)}})
    end
    if (nil ~= t_46_) then
      t_46_ = t_46_[1]
    else
    end
    return t_46_
  else
    return nil
  end
end
M["thread-id-for-gh"] = function(gh_id)
  if gh_id then
    local t_49_ = M["comment-by-gh"](gh_id)
    if (nil ~= t_49_) then
      t_49_ = t_49_.thread_id
    else
    end
    return t_49_
  else
    return nil
  end
end
M["with-gh-user"] = function(login)
  local email = ((login or "unknown") .. "@users.noreply.github.com")
  local entry_3f
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    entry_3f = t_2_auto:get({where = {email = email}})
  end
  local _53_
  do
    local t_52_ = entry_3f
    if (nil ~= t_52_) then
      t_52_ = t_52_[1]
    else
    end
    if (nil ~= t_52_) then
      t_52_ = t_52_.id
    else
    end
    _53_ = t_52_
  end
  if _53_ then
    local t_56_ = entry_3f
    if (nil ~= t_56_) then
      t_56_ = t_56_[1]
    else
    end
    if (nil ~= t_56_) then
      t_56_ = t_56_.id
    else
    end
    return t_56_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    return t_2_auto:insert({name = (login or "unknown"), email = email})
  end
end
M["import-thread"] = function(session_id, item)
  local repo_id = with_repo()
  local login
  do
    local t_60_ = item
    if (nil ~= t_60_) then
      t_60_ = t_60_.user
    else
    end
    if (nil ~= t_60_) then
      t_60_ = t_60_.login
    else
    end
    login = t_60_
  end
  local line = (item.line or item.original_line or 1)
  local commit_id = with_commit(repo_id, item.commit_id)
  local thread_id
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local _63_
    if not item.position then
      _63_ = 1
    else
      _63_ = nil
    end
    thread_id = t_2_auto:insert({session_id = session_id, file_path = item.path, line_start = line, line_end = line, anchor_commit = commit_id, status = "open", gh_outdated = _63_, created_by = M["with-gh-user"](login)})
  end
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
    t_2_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](login), body = item.body, source = "github", commit_id = commit_id, gh_comment_id = tostring(item.id)})
  end
  return thread_id
end
M["import-comment"] = function(thread_id, item)
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
  local function _66_()
    local t_65_ = item
    if (nil ~= t_65_) then
      t_65_ = t_65_.user
    else
    end
    if (nil ~= t_65_) then
      t_65_ = t_65_.login
    else
    end
    return t_65_
  end
  return t_2_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](_66_()), body = item.body, source = "github", commit_id = with_commit(with_repo(), item.commit_id), gh_comment_id = tostring(item.id)})
end
M["gh-root-comment-id"] = function(thread_id)
  local root = nil
  for _, c in ipairs(M["comments-for"](thread_id)) do
    root = (root or c.gh_comment_id)
  end
  return root
end
M["agent-reply"] = function(thread_id, body)
  local rows
  local _69_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    _69_ = t_2_auto:get({where = {id = thread_id}})
  end
  rows = (_69_ or {})
  local thread = rows[1]
  if (not thread or thread.deleted_at or (thread.status == "resolved")) then
    vim.notify(("codeboomer: no active thread #" .. tostring(thread_id)), vim.log.levels.ERROR)
    return nil
  elseif ("" == (body or "")) then
    vim.notify("codeboomer: empty reply body", vim.log.levels.ERROR)
    return nil
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
    return t_2_auto:insert({thread_id = thread_id, author_id = with_agent_user(), body = body, source = "agent", commit_id = thread.anchor_commit})
  end
end
M["user-reply"] = function(thread_id, body)
  local rows
  local _71_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    _71_ = t_2_auto:get({where = {id = thread_id}})
  end
  rows = (_71_ or {})
  local thread = rows[1]
  if (not thread or thread.deleted_at or (thread.status == "resolved")) then
    vim.notify(("codeboomer: no active thread #" .. tostring(thread_id)), vim.log.levels.ERROR)
    return nil
  elseif ("" == (body or "")) then
    vim.notify("codeboomer: empty reply body", vim.log.levels.ERROR)
    return nil
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
    return t_2_auto:insert({thread_id = thread_id, author_id = with_user(), body = body, source = "user", commit_id = thread.anchor_commit})
  end
end
M["resolve-thread"] = function(thread_id)
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
  return t_2_auto:update({set = {status = "resolved"}, where = {id = thread_id}})
end
M["commit-sha"] = function(commit_id)
  local t_73_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
    t_73_ = t_2_auto:get({where = {id = commit_id}})
  end
  if (nil ~= t_73_) then
    t_73_ = t_73_[1]
  else
  end
  if (nil ~= t_73_) then
    t_73_ = t_73_.hash
  else
  end
  return t_73_
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
    local function _78_(d)
      for _, id in ipairs(ids) do
        d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
      end
      return nil
    end
    return s["get-db"]():with_open(_78_)
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
  local rows
  local _81_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    _81_ = t_2_auto:get({where = {session_id = session_id}})
  end
  rows = unresolved_rows(sqlite["active-rows"]((_81_ or {})))
  local function _82_(a, b)
    local pa = (a.file_path or "")
    local pb = (b.file_path or "")
    if (pa == pb) then
      return ((a.line_start or 0) < (b.line_start or 0))
    else
      return (pa < pb)
    end
  end
  table.sort(rows, _82_)
  return rows
end
M["comments-for"] = function(thread_id)
  local rows
  local _84_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
    _84_ = t_2_auto:get({where = {thread_id = thread_id}})
  end
  rows = sqlite["active-rows"]((_84_ or {}))
  local function _85_(a, b)
    local ta = (a.created_at or 0)
    local tb = (b.created_at or 0)
    if (ta == tb) then
      return ((a.id or 0) < (b.id or 0))
    else
      return (ta < tb)
    end
  end
  table.sort(rows, _85_)
  return rows
end
M["create-session"] = function(_3fopts)
  local opts = (_3fopts or {})
  local repo_id = with_repo()
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
  local function _88_()
    local t_87_ = opts
    if (nil ~= t_87_) then
      t_87_ = t_87_["head-sha"]
    else
    end
    return t_87_
  end
  local function _91_()
    local t_90_ = opts
    if (nil ~= t_90_) then
      t_90_ = t_90_["base-sha"]
    else
    end
    return t_90_
  end
  return t_2_auto:insert({branch = (opts.branch or git["branch-name"]()), head_commit = with_commit(repo_id, _88_()), base_commit = with_commit(repo_id, _91_()), repo_id = repo_id, pr_number = opts["pr-number"]})
end
return M
