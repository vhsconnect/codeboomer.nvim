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
    thread_id = t_2_auto:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = code, anchor_commit = commit_id, status = "open", kind = "local", created_by = user_id})
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
M["session-for-pr"] = function(pr_number)
  if pr_number then
    local root = git["repo-root"]()
    if root then
      local repo_id
      do
        local t_30_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
          t_30_ = t_2_auto:get({where = {path = root}})
        end
        if (nil ~= t_30_) then
          t_30_ = t_30_[1]
        else
        end
        if (nil ~= t_30_) then
          t_30_ = t_30_.id
        else
        end
        repo_id = t_30_
      end
      if repo_id then
        local t_33_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          t_33_ = t_2_auto:get({where = {repo_id = repo_id, pr_number = pr_number}})
        end
        if (nil ~= t_33_) then
          t_33_ = t_33_[1]
        else
        end
        return t_33_
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
    local t_38_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
      t_38_ = t_2_auto:get({where = {id = id}})
    end
    if (nil ~= t_38_) then
      t_38_ = t_38_[1]
    else
    end
    return t_38_
  else
    return nil
  end
end
M["comment-by-gh"] = function(gh_id)
  if gh_id then
    local t_41_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
      t_41_ = t_2_auto:get({where = {gh_comment_id = tostring(gh_id)}})
    end
    if (nil ~= t_41_) then
      t_41_ = t_41_[1]
    else
    end
    return t_41_
  else
    return nil
  end
end
M["thread-id-for-gh"] = function(gh_id)
  if gh_id then
    local t_44_ = M["comment-by-gh"](gh_id)
    if (nil ~= t_44_) then
      t_44_ = t_44_.thread_id
    else
    end
    return t_44_
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
  local _48_
  do
    local t_47_ = entry_3f
    if (nil ~= t_47_) then
      t_47_ = t_47_[1]
    else
    end
    if (nil ~= t_47_) then
      t_47_ = t_47_.id
    else
    end
    _48_ = t_47_
  end
  if _48_ then
    local t_51_ = entry_3f
    if (nil ~= t_51_) then
      t_51_ = t_51_[1]
    else
    end
    if (nil ~= t_51_) then
      t_51_ = t_51_.id
    else
    end
    return t_51_
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
    local t_55_ = item
    if (nil ~= t_55_) then
      t_55_ = t_55_.user
    else
    end
    if (nil ~= t_55_) then
      t_55_ = t_55_.login
    else
    end
    login = t_55_
  end
  local line = (item.line or item.original_line or 1)
  local commit_id = with_commit(repo_id, item.commit_id)
  local thread_id
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local _58_
    if not item.position then
      _58_ = 1
    else
      _58_ = nil
    end
    thread_id = t_2_auto:insert({session_id = session_id, file_path = item.path, line_start = line, line_end = line, anchor_commit = commit_id, status = "open", kind = "review", gh_outdated = _58_, created_by = M["with-gh-user"](login)})
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
  local function _61_()
    local t_60_ = item
    if (nil ~= t_60_) then
      t_60_ = t_60_.user
    else
    end
    if (nil ~= t_60_) then
      t_60_ = t_60_.login
    else
    end
    return t_60_
  end
  return t_2_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](_61_()), body = item.body, source = "github", commit_id = with_commit(with_repo(), item.commit_id), gh_comment_id = tostring(item.id)})
end
M["gh-root-comment-id"] = function(thread_id)
  local root = nil
  for _, c in ipairs(M["comments-for"](thread_id)) do
    root = (root or c.gh_comment_id)
  end
  return root
end
local function by_file_then_line(a, b)
  local pa = (a.file_path or "")
  local pb = (b.file_path or "")
  if (pa == pb) then
    return ((a.line_start or 0) < (b.line_start or 0))
  else
    return (pa < pb)
  end
end
local function by_created(a, b)
  local ta = (a.created_at or 0)
  local tb = (b.created_at or 0)
  if (ta == tb) then
    return ((a.id or 0) < (b.id or 0))
  else
    return (ta < tb)
  end
end
local function thread_by_id(id)
  local t_66_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    t_66_ = t_2_auto:get({where = {id = (id or 0)}})
  end
  if (nil ~= t_66_) then
    t_66_ = t_66_[1]
  else
  end
  return t_66_
end
local function root_of(t)
  local _68_
  if t.parent_id then
    _68_ = thread_by_id(t.parent_id)
  else
    _68_ = nil
  end
  return (_68_ or t)
end
local function twin_of(t)
  local root = root_of(t)
  if ((root.id or 0) == (t.id or 0)) then
    local t_70_
    local function _71_()
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      return t_2_auto:get({where = {parent_id = (t.id or 0)}})
    end
    t_70_ = sqlite["active-rows"](_71_())
    if (nil ~= t_70_) then
      t_70_ = t_70_[1]
    else
    end
    return t_70_
  else
    return root
  end
end
M.twin = function(id)
  local t = thread_by_id(id)
  if t then
    return twin_of(t)
  else
    return nil
  end
end
M["conversation-comments"] = function(thread_id)
  local t = thread_by_id(thread_id)
  if not t then
    return {}
  else
    local root = root_of(t)
    local twin = twin_of(t)
    local rows
    local function _75_()
      if (twin and ((twin.id or 0) ~= (root.id or 0))) then
        return M["comments-for"](twin.id)
      else
        return {}
      end
    end
    rows = vim.list_extend(M["comments-for"]((root.id or 0)), _75_())
    table.sort(rows, by_created)
    return rows
  end
end
M["ensure-local-twin"] = function(thread_id)
  local t = thread_by_id(thread_id)
  if not t then
    return nil
  else
    local twin = twin_of(t)
    if twin then
      return twin
    else
      local id
      do
        local db_mod_1_auto = require("codeboomer.singleton")
        local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
        id = t_2_auto:insert({session_id = t.session_id, file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = t.code_snapshot, anchor_commit = t.anchor_commit, status = "open", kind = "local", parent_id = t.id, created_by = with_user()})
      end
      return thread_by_id(id)
    end
  end
end
M.promote = function(thread_id, body, _3fsession_id, _3fanchor_sha)
  local t = thread_by_id(thread_id)
  local refuse
  local function _79_(msg, level)
    vim.notify(msg, level)
    return nil
  end
  refuse = _79_
  if not t then
    return refuse(("codeboomer: no thread #" .. tostring((thread_id or 0))), vim.log.levels.ERROR)
  elseif ("review" == (t.kind or "local")) then
    return refuse("codeboomer: this thread is already a review thread", vim.log.levels.WARN)
  elseif twin_of(t) then
    return refuse(string.format("codeboomer: thread #%d already promoted", (t.id or 0)), vim.log.levels.WARN)
  elseif ("" == vim.trim((body or ""))) then
    return refuse("codeboomer: empty promotion ignored", vim.log.levels.WARN)
  else
    local commit_id = with_commit(with_repo(), (_3fanchor_sha or M["commit-sha"](t.anchor_commit)))
    local twin_id
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      twin_id = t_2_auto:insert({session_id = (_3fsession_id or t.session_id), file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = t.code_snapshot, anchor_commit = commit_id, status = "open", kind = "review", parent_id = t.id, created_by = with_user()})
    end
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
      t_2_auto:insert({thread_id = twin_id, author_id = with_user(), body = body, source = "user", commit_id = commit_id})
    end
    return twin_id
  end
end
M["update-comment-body"] = function(comment_id, body)
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
  return t_2_auto:update({set = {body = body}, where = {id = (comment_id or 0)}})
end
M["stamp-gh-comment"] = function(comment_id, gh_id)
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
  return t_2_auto:update({set = {gh_comment_id = tostring(gh_id)}, where = {id = (comment_id or 0)}})
end
M["agent-reply"] = function(thread_id, body)
  local rows
  local _81_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    _81_ = t_2_auto:get({where = {id = thread_id}})
  end
  rows = (_81_ or {})
  local thread = rows[1]
  if (not thread or thread.deleted_at or (thread.status == "resolved")) then
    vim.notify(("codeboomer: no active thread #" .. tostring(thread_id)), vim.log.levels.ERROR)
    return nil
  elseif ("" == (body or "")) then
    vim.notify("codeboomer: empty reply body", vim.log.levels.ERROR)
    return nil
  else
    local target
    if ("review" == (thread.kind or "local")) then
      target = M["ensure-local-twin"](thread_id)
    else
      target = thread
    end
    if target then
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
      return t_2_auto:insert({thread_id = target.id, author_id = with_agent_user(), body = body, source = "agent", commit_id = target.anchor_commit})
    else
      return nil
    end
  end
end
M["user-reply"] = function(thread_id, body)
  local rows
  local _85_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    _85_ = t_2_auto:get({where = {id = thread_id}})
  end
  rows = (_85_ or {})
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
  local t = thread_by_id(thread_id)
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    t_2_auto:update({set = {status = "resolved"}, where = {id = thread_id}})
  end
  local twin
  if t then
    twin = twin_of(t)
  else
    twin = nil
  end
  if twin then
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    return t_2_auto:update({set = {status = "resolved"}, where = {id = twin.id}})
  else
    return nil
  end
end
M["commit-sha"] = function(commit_id)
  local t_89_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
    t_89_ = t_2_auto:get({where = {id = commit_id}})
  end
  if (nil ~= t_89_) then
    t_89_ = t_89_[1]
  else
  end
  if (nil ~= t_89_) then
    t_89_ = t_89_.hash
  else
  end
  return t_89_
end
local function mine_unflagged_3f(c, me, flag)
  return (((c.author_id or 0) == me) and ((c.source or "user") == "user") and (0 == (c[flag] or 0)) and ("" ~= (c.body or "")))
end
M["unposted-user-comments"] = function(thread_id)
  local me = with_user()
  local tbl_26_ = {}
  local i_27_ = 0
  for _, c in ipairs(M["comments-for"]((thread_id or 0))) do
    local val_28_
    if mine_unflagged_3f(c, me, "posted") then
      val_28_ = c
    else
      val_28_ = nil
    end
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
M["pending-for-flush"] = function(session_id)
  if not session_id then
    return {}
  else
    local me = with_user()
    local out = {}
    for _, t in ipairs(M["threads-for-session"](session_id)) do
      for _0, c in ipairs(M["conversation-comments"]((t.id or 0))) do
        if mine_unflagged_3f(c, me, "sent") then
          table.insert(out, {thread = t, comment = c})
        else
        end
      end
    end
    return out
  end
end
M["pending-for-post"] = function(session_id)
  if not session_id then
    return {}
  else
    local me = with_user()
    local out = {}
    for _, t in ipairs(M["review-rows-for-session"](session_id)) do
      for _0, c in ipairs(M["comments-for"]((t.id or 0))) do
        if mine_unflagged_3f(c, me, "posted") then
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
    local function _98_(d)
      for _, id in ipairs(ids) do
        d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
      end
      return nil
    end
    return s["get-db"]():with_open(_98_)
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
  if not session_id then
    return {}
  else
    local rows
    local _101_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      _101_ = t_2_auto:get({where = {session_id = session_id}})
    end
    rows = unresolved_rows(sqlite["active-rows"]((_101_ or {})))
    local seen = {}
    local roots = {}
    for _, row in ipairs(rows) do
      local root = root_of(row)
      if (root and not seen[(root.id or 0)]) then
        seen[(root.id or 0)] = true
        table.insert(roots, root)
      else
      end
    end
    table.sort(roots, by_file_then_line)
    return roots
  end
end
M["review-rows-for-session"] = function(session_id)
  if not session_id then
    return {}
  else
    local rows
    local _104_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      _104_ = t_2_auto:get({where = {session_id = session_id, kind = "review"}})
    end
    rows = unresolved_rows(sqlite["active-rows"]((_104_ or {})))
    table.sort(rows, by_file_then_line)
    return rows
  end
end
M["comments-for"] = function(thread_id)
  local rows
  local _106_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
    _106_ = t_2_auto:get({where = {thread_id = thread_id}})
  end
  rows = sqlite["active-rows"]((_106_ or {}))
  table.sort(rows, by_created)
  return rows
end
M["comment-author"] = function(c)
  local t_107_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    t_107_ = t_2_auto:get({where = {id = (c.author_id or 0)}})
  end
  if (nil ~= t_107_) then
    t_107_ = t_107_[1]
  else
  end
  return t_107_
end
M["match-posted-comment"] = function(session_id, item)
  local line = (item.line or item.original_line)
  local want_path = (item.path or "")
  local want_body = (item.body or "")
  local found = nil
  for _, r in ipairs(M["review-rows-for-session"](session_id)) do
    if found then break end
    if (want_path == (r.file_path or "")) then
      for _0, c in ipairs(M["comments-for"]((r.id or 0))) do
        if found then break end
        if (line and (1 == (c.posted or 0)) and (nil == c.gh_comment_id) and (want_body == (c.body or "")) and (line >= (r.line_start or 0)) and (line <= (r.line_end or 0))) then
          found = c
        else
        end
      end
    else
    end
  end
  return found
end
M["create-session"] = function(_3fopts)
  local opts = (_3fopts or {})
  local repo_id = with_repo()
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
  local function _112_()
    local t_111_ = opts
    if (nil ~= t_111_) then
      t_111_ = t_111_["head-sha"]
    else
    end
    return t_111_
  end
  local function _115_()
    local t_114_ = opts
    if (nil ~= t_114_) then
      t_114_ = t_114_["base-sha"]
    else
    end
    return t_114_
  end
  return t_2_auto:insert({branch = (opts.branch or git["branch-name"]()), head_commit = with_commit(repo_id, _112_()), base_commit = with_commit(repo_id, _115_()), repo_id = repo_id, pr_number = opts["pr-number"]})
end
return M
