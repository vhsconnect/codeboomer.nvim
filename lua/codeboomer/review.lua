-- [nfnl] fnl/codeboomer/review.fnl
vim = vim
local git = require("codeboomer.git")
local sqlite = require("codeboomer.sqlite")
local s = require("codeboomer.singleton")
local M = {}
local function sql_literal(_3ftext)
  local v = (_3ftext or "")
  if v:match("^[%S]+%(.*%)$") then
    return (" " .. v)
  else
    return v
  end
end
local function with_user()
  local email = git["user-email"]()
  local entry_3f
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _2_()
      return t_2_auto:get({where = {email = email}})
    end
    ok_3_auto, result_4_auto = pcall(_2_)
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_4_ = entry_3f
    if (nil ~= t_4_) then
      t_4_ = t_4_[1]
    else
    end
    if (nil ~= t_4_) then
      t_4_ = t_4_.id
    else
    end
    return t_4_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _7_()
      return t_2_auto:insert({name = git["user-name"](), email = email})
    end
    ok_3_auto, result_4_auto = pcall(_7_)
    if ok_3_auto then
      return result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      return error(result_4_auto, 0)
    end
  end
end
local function with_agent_user()
  local entry_3f
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _10_()
      return t_2_auto:get({where = {email = "agent@codeboomer"}})
    end
    ok_3_auto, result_4_auto = pcall(_10_)
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_12_ = entry_3f
    if (nil ~= t_12_) then
      t_12_ = t_12_[1]
    else
    end
    if (nil ~= t_12_) then
      t_12_ = t_12_.id
    else
    end
    return t_12_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _15_()
      return t_2_auto:insert({name = "agent", email = "agent@codeboomer"})
    end
    ok_3_auto, result_4_auto = pcall(_15_)
    if ok_3_auto then
      return result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      return error(result_4_auto, 0)
    end
  end
end
local function with_repo()
  local repo_path = git["repo-root"]()
  local entry_3f
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _18_()
      return t_2_auto:get({where = {path = repo_path}})
    end
    ok_3_auto, result_4_auto = pcall(_18_)
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_20_ = entry_3f
    if (nil ~= t_20_) then
      t_20_ = t_20_[1]
    else
    end
    if (nil ~= t_20_) then
      t_20_ = t_20_.id
    else
    end
    return t_20_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _23_()
      return t_2_auto:insert({path = repo_path})
    end
    ok_3_auto, result_4_auto = pcall(_23_)
    if ok_3_auto then
      return result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      return error(result_4_auto, 0)
    end
  end
end
local function with_commit(repo_id, _3fsha)
  local commit_hash = (_3fsha or git["head-sha"]())
  if commit_hash then
    local entry_3f
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _26_()
        return t_2_auto:get({where = {hash = commit_hash}})
      end
      ok_3_auto, result_4_auto = pcall(_26_)
      if ok_3_auto then
        entry_3f = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        entry_3f = error(result_4_auto, 0)
      end
    end
    local _29_
    do
      local t_28_ = entry_3f
      if (nil ~= t_28_) then
        t_28_ = t_28_[1]
      else
      end
      if (nil ~= t_28_) then
        t_28_ = t_28_.id
      else
      end
      _29_ = t_28_
    end
    if _29_ then
      local t_32_ = entry_3f
      if (nil ~= t_32_) then
        t_32_ = t_32_[1]
      else
      end
      if (nil ~= t_32_) then
        t_32_ = t_32_.id
      else
      end
      return t_32_
    else
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _35_()
        return t_2_auto:insert({hash = commit_hash, repo = repo_id})
      end
      ok_3_auto, result_4_auto = pcall(_35_)
      if ok_3_auto then
        return result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        return error(result_4_auto, 0)
      end
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
    local ok_3_auto, result_4_auto
    local function _39_()
      return t_2_auto:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = sql_literal(code), anchor_commit = commit_id, status = "open", type = "line", kind = "local", created_by = user_id})
    end
    ok_3_auto, result_4_auto = pcall(_39_)
    if ok_3_auto then
      thread_id = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      thread_id = error(result_4_auto, 0)
    end
  end
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
  local ok_3_auto, result_4_auto
  local function _41_()
    return t_2_auto:insert({thread_id = thread_id, author_id = user_id, body = sql_literal(body), source = "user", commit_id = commit_id})
  end
  ok_3_auto, result_4_auto = pcall(_41_)
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
end
M["file-comment"] = function(session_id, file_path, body)
  local user_id = with_user()
  local repo_id = with_repo()
  local commit_id = with_commit(repo_id)
  local thread_id
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _43_()
      return t_2_auto:insert({session_id = session_id, file_path = file_path, anchor_commit = commit_id, status = "open", type = "file", kind = "local", created_by = user_id})
    end
    ok_3_auto, result_4_auto = pcall(_43_)
    if ok_3_auto then
      thread_id = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      thread_id = error(result_4_auto, 0)
    end
  end
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
  local ok_3_auto, result_4_auto
  local function _45_()
    return t_2_auto:insert({thread_id = thread_id, author_id = user_id, body = sql_literal(body), source = "user", commit_id = commit_id})
  end
  ok_3_auto, result_4_auto = pcall(_45_)
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
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
      local t_48_
      do
        local db_mod_1_auto = require("codeboomer.singleton")
        local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
        local ok_3_auto, result_4_auto
        local function _49_()
          return t_2_auto:get({where = {path = root}})
        end
        ok_3_auto, result_4_auto = pcall(_49_)
        if ok_3_auto then
          t_48_ = result_4_auto
        else
          db_mod_1_auto["reset-db"]()
          t_48_ = error(result_4_auto, 0)
        end
      end
      if (nil ~= t_48_) then
        t_48_ = t_48_[1]
      else
      end
      if (nil ~= t_48_) then
        t_48_ = t_48_.id
      else
      end
      repo_id = t_48_
    end
    if repo_id then
      local sessions
      do
        local tbl_26_ = {}
        local i_27_ = 0
        local _53_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _54_()
            return t_2_auto:get({where = {repo_id = repo_id}})
          end
          ok_3_auto, result_4_auto = pcall(_54_)
          if ok_3_auto then
            _53_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            _53_ = error(result_4_auto, 0)
          end
        end
        for _, row in ipairs(sqlite["active-rows"]((_53_ or {}))) do
          local val_28_
          if (row.pr_number == nil) then
            val_28_ = row
          else
            val_28_ = nil
          end
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        sessions = tbl_26_
      end
      local function _58_(a, b)
        return ((a.id or 0) < (b.id or 0))
      end
      table.sort(sessions, _58_)
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
        local t_61_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _62_()
            return t_2_auto:get({where = {path = root}})
          end
          ok_3_auto, result_4_auto = pcall(_62_)
          if ok_3_auto then
            t_61_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            t_61_ = error(result_4_auto, 0)
          end
        end
        if (nil ~= t_61_) then
          t_61_ = t_61_[1]
        else
        end
        if (nil ~= t_61_) then
          t_61_ = t_61_.id
        else
        end
        repo_id = t_61_
      end
      if repo_id then
        local t_66_
        local function _68_()
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _67_()
            return t_2_auto:get({where = {repo_id = repo_id, pr_number = pr_number}})
          end
          ok_3_auto, result_4_auto = pcall(_67_)
          if ok_3_auto then
            return result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            return error(result_4_auto, 0)
          end
        end
        t_66_ = sqlite["active-rows"](_68_())
        if (nil ~= t_66_) then
          t_66_ = t_66_[1]
        else
        end
        return t_66_
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
M["session-for-branch"] = function(branch)
  if branch then
    local root = git["repo-root"]()
    if root then
      local repo_id
      do
        local t_74_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _75_()
            return t_2_auto:get({where = {path = root}})
          end
          ok_3_auto, result_4_auto = pcall(_75_)
          if ok_3_auto then
            t_74_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            t_74_ = error(result_4_auto, 0)
          end
        end
        if (nil ~= t_74_) then
          t_74_ = t_74_[1]
        else
        end
        if (nil ~= t_74_) then
          t_74_ = t_74_.id
        else
        end
        repo_id = t_74_
      end
      if repo_id then
        local found = nil
        local _79_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _80_()
            return t_2_auto:get({where = {repo_id = repo_id, branch = branch}})
          end
          ok_3_auto, result_4_auto = pcall(_80_)
          if ok_3_auto then
            _79_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            _79_ = error(result_4_auto, 0)
          end
        end
        for _, row in ipairs(sqlite["active-rows"]((_79_ or {}))) do
          if (not found and (row.pr_number == nil)) then
            found = row
          else
          end
        end
        return found
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
    local t_86_
    local function _88_()
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _87_()
        return t_2_auto:get({where = {id = id}})
      end
      ok_3_auto, result_4_auto = pcall(_87_)
      if ok_3_auto then
        return result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        return error(result_4_auto, 0)
      end
    end
    t_86_ = sqlite["active-rows"](_88_())
    if (nil ~= t_86_) then
      t_86_ = t_86_[1]
    else
    end
    return t_86_
  else
    return nil
  end
end
M["comment-by-gh"] = function(gh_id)
  if gh_id then
    local t_92_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _93_()
        return t_2_auto:get({where = {gh_comment_id = tostring(gh_id)}})
      end
      ok_3_auto, result_4_auto = pcall(_93_)
      if ok_3_auto then
        t_92_ = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        t_92_ = error(result_4_auto, 0)
      end
    end
    if (nil ~= t_92_) then
      t_92_ = t_92_[1]
    else
    end
    return t_92_
  else
    return nil
  end
end
M["thread-id-for-gh"] = function(gh_id)
  if gh_id then
    local t_97_ = M["comment-by-gh"](gh_id)
    if (nil ~= t_97_) then
      t_97_ = t_97_.thread_id
    else
    end
    return t_97_
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
    local ok_3_auto, result_4_auto
    local function _100_()
      return t_2_auto:get({where = {email = email}})
    end
    ok_3_auto, result_4_auto = pcall(_100_)
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  local _103_
  do
    local t_102_ = entry_3f
    if (nil ~= t_102_) then
      t_102_ = t_102_[1]
    else
    end
    if (nil ~= t_102_) then
      t_102_ = t_102_.id
    else
    end
    _103_ = t_102_
  end
  if _103_ then
    local t_106_ = entry_3f
    if (nil ~= t_106_) then
      t_106_ = t_106_[1]
    else
    end
    if (nil ~= t_106_) then
      t_106_ = t_106_.id
    else
    end
    return t_106_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _109_()
      return t_2_auto:insert({name = (login or "unknown"), email = email})
    end
    ok_3_auto, result_4_auto = pcall(_109_)
    if ok_3_auto then
      return result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      return error(result_4_auto, 0)
    end
  end
end
M["import-thread"] = function(session_id, item)
  local repo_id = with_repo()
  local login
  do
    local t_112_ = item
    if (nil ~= t_112_) then
      t_112_ = t_112_.user
    else
    end
    if (nil ~= t_112_) then
      t_112_ = t_112_.login
    else
    end
    login = t_112_
  end
  local file_3f = ("file" == item.subject_type)
  local line
  if not file_3f then
    line = (item.line or item.original_line or 1)
  else
    line = nil
  end
  local commit_id = with_commit(repo_id, item.commit_id)
  local thread_id
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _116_()
      local _117_
      if file_3f then
        _117_ = "file"
      else
        _117_ = "line"
      end
      local _119_
      if (not file_3f and not item.position) then
        _119_ = 1
      else
        _119_ = nil
      end
      return t_2_auto:insert({session_id = session_id, file_path = item.path, line_start = line, line_end = line, anchor_commit = commit_id, status = "open", type = _117_, kind = "review", gh_outdated = _119_, created_by = M["with-gh-user"](login)})
    end
    ok_3_auto, result_4_auto = pcall(_116_)
    if ok_3_auto then
      thread_id = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      thread_id = error(result_4_auto, 0)
    end
  end
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _122_()
      return t_2_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](login), body = sql_literal(item.body), source = "github", commit_id = commit_id, gh_comment_id = tostring(item.id)})
    end
    ok_3_auto, result_4_auto = pcall(_122_)
    if ok_3_auto then
    else
      db_mod_1_auto["reset-db"]()
      error(result_4_auto, 0)
    end
  end
  return thread_id
end
M["import-comment"] = function(thread_id, item)
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
  local ok_3_auto, result_4_auto
  local function _124_()
    local function _126_()
      local t_125_ = item
      if (nil ~= t_125_) then
        t_125_ = t_125_.user
      else
      end
      if (nil ~= t_125_) then
        t_125_ = t_125_.login
      else
      end
      return t_125_
    end
    return t_2_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](_126_()), body = sql_literal(item.body), source = "github", commit_id = with_commit(with_repo(), item.commit_id), gh_comment_id = tostring(item.id)})
  end
  ok_3_auto, result_4_auto = pcall(_124_)
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
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
  local t_132_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _133_()
      return t_2_auto:get({where = {id = (id or 0)}})
    end
    ok_3_auto, result_4_auto = pcall(_133_)
    if ok_3_auto then
      t_132_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      t_132_ = error(result_4_auto, 0)
    end
  end
  if (nil ~= t_132_) then
    t_132_ = t_132_[1]
  else
  end
  return t_132_
end
local function root_of(t)
  local _136_
  if t.parent_id then
    _136_ = thread_by_id(t.parent_id)
  else
    _136_ = nil
  end
  return (_136_ or t)
end
local function twin_of(t)
  local root = root_of(t)
  if ((root.id or 0) == (t.id or 0)) then
    local t_138_
    local function _140_()
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _139_()
        return t_2_auto:get({where = {parent_id = (t.id or 0)}})
      end
      ok_3_auto, result_4_auto = pcall(_139_)
      if ok_3_auto then
        return result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        return error(result_4_auto, 0)
      end
    end
    t_138_ = sqlite["active-rows"](_140_())
    if (nil ~= t_138_) then
      t_138_ = t_138_[1]
    else
    end
    return t_138_
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
    local function _145_()
      if (twin and ((twin.id or 0) ~= (root.id or 0))) then
        return M["comments-for"](twin.id)
      else
        return {}
      end
    end
    rows = vim.list_extend(M["comments-for"]((root.id or 0)), _145_())
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
        local ok_3_auto, result_4_auto
        local function _147_()
          return t_2_auto:insert({session_id = t.session_id, file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = t.anchor_commit, status = "open", type = (t.type or "line"), kind = "local", parent_id = t.id, created_by = with_user()})
        end
        ok_3_auto, result_4_auto = pcall(_147_)
        if ok_3_auto then
          id = result_4_auto
        else
          db_mod_1_auto["reset-db"]()
          id = error(result_4_auto, 0)
        end
      end
      return thread_by_id(id)
    end
  end
end
M.promote = function(thread_id, body, _3fsession_id, _3fanchor_sha)
  local t = thread_by_id(thread_id)
  local refuse
  local function _151_(msg, level)
    vim.notify(msg, level)
    return nil
  end
  refuse = _151_
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
      local ok_3_auto, result_4_auto
      local function _152_()
        return t_2_auto:insert({session_id = (_3fsession_id or t.session_id), file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = commit_id, status = "open", type = (t.type or "line"), kind = "review", parent_id = t.id, created_by = with_user()})
      end
      ok_3_auto, result_4_auto = pcall(_152_)
      if ok_3_auto then
        twin_id = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        twin_id = error(result_4_auto, 0)
      end
    end
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _154_()
        return t_2_auto:insert({thread_id = twin_id, author_id = with_user(), body = sql_literal(body), source = "user", commit_id = commit_id})
      end
      ok_3_auto, result_4_auto = pcall(_154_)
      if ok_3_auto then
      else
        db_mod_1_auto["reset-db"]()
        error(result_4_auto, 0)
      end
    end
    return twin_id
  end
end
M["update-comment-body"] = function(comment_id, body)
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
  local ok_3_auto, result_4_auto
  local function _157_()
    return t_2_auto:update({set = {body = sql_literal(body)}, where = {id = (comment_id or 0)}})
  end
  ok_3_auto, result_4_auto = pcall(_157_)
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
end
M["stamp-gh-comment"] = function(comment_id, gh_id)
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
  local ok_3_auto, result_4_auto
  local function _159_()
    return t_2_auto:update({set = {gh_comment_id = tostring(gh_id)}, where = {id = (comment_id or 0)}})
  end
  ok_3_auto, result_4_auto = pcall(_159_)
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
end
M["agent-reply"] = function(thread_id, body)
  local rows
  local _161_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _162_()
      return t_2_auto:get({where = {id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_162_)
    if ok_3_auto then
      _161_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      _161_ = error(result_4_auto, 0)
    end
  end
  rows = (_161_ or {})
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
      local ok_3_auto, result_4_auto
      local function _165_()
        return t_2_auto:insert({thread_id = target.id, author_id = with_agent_user(), body = sql_literal(body), source = "agent", commit_id = target.anchor_commit})
      end
      ok_3_auto, result_4_auto = pcall(_165_)
      if ok_3_auto then
        return result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        return error(result_4_auto, 0)
      end
    else
      return nil
    end
  end
end
M["user-reply"] = function(thread_id, body)
  local rows
  local _169_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _170_()
      return t_2_auto:get({where = {id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_170_)
    if ok_3_auto then
      _169_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      _169_ = error(result_4_auto, 0)
    end
  end
  rows = (_169_ or {})
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
    local ok_3_auto, result_4_auto
    local function _172_()
      return t_2_auto:insert({thread_id = thread_id, author_id = with_user(), body = sql_literal(body), source = "user", commit_id = thread.anchor_commit})
    end
    ok_3_auto, result_4_auto = pcall(_172_)
    if ok_3_auto then
      return result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      return error(result_4_auto, 0)
    end
  end
end
M["resolve-thread"] = function(thread_id)
  local t = thread_by_id(thread_id)
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _175_()
      return t_2_auto:update({set = {status = "resolved"}, where = {id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_175_)
    if ok_3_auto then
    else
      db_mod_1_auto["reset-db"]()
      error(result_4_auto, 0)
    end
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
    local ok_3_auto, result_4_auto
    local function _178_()
      return t_2_auto:update({set = {status = "resolved"}, where = {id = twin.id}})
    end
    ok_3_auto, result_4_auto = pcall(_178_)
    if ok_3_auto then
      return result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      return error(result_4_auto, 0)
    end
  else
    return nil
  end
end
M["commit-sha"] = function(commit_id)
  local t_181_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _182_()
      return t_2_auto:get({where = {id = commit_id}})
    end
    ok_3_auto, result_4_auto = pcall(_182_)
    if ok_3_auto then
      t_181_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      t_181_ = error(result_4_auto, 0)
    end
  end
  if (nil ~= t_181_) then
    t_181_ = t_181_[1]
  else
  end
  if (nil ~= t_181_) then
    t_181_ = t_181_.hash
  else
  end
  return t_181_
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
    local function _192_(d)
      for _, id in ipairs(ids) do
        d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
      end
      return nil
    end
    return s["get-db"]():with_open(_192_)
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
  if not M["session-by-id"](session_id) then
    return {}
  else
    local rows
    local _195_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _196_()
        return t_2_auto:get({where = {session_id = session_id}})
      end
      ok_3_auto, result_4_auto = pcall(_196_)
      if ok_3_auto then
        _195_ = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        _195_ = error(result_4_auto, 0)
      end
    end
    rows = unresolved_rows(sqlite["active-rows"]((_195_ or {})))
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
  if not M["session-by-id"](session_id) then
    return {}
  else
    local rows
    local _200_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _201_()
        return t_2_auto:get({where = {session_id = session_id, kind = "review"}})
      end
      ok_3_auto, result_4_auto = pcall(_201_)
      if ok_3_auto then
        _200_ = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        _200_ = error(result_4_auto, 0)
      end
    end
    rows = unresolved_rows(sqlite["active-rows"]((_200_ or {})))
    table.sort(rows, by_file_then_line)
    return rows
  end
end
M["comments-for"] = function(thread_id)
  local rows
  local _204_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _205_()
      return t_2_auto:get({where = {thread_id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_205_)
    if ok_3_auto then
      _204_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      _204_ = error(result_4_auto, 0)
    end
  end
  rows = sqlite["active-rows"]((_204_ or {}))
  table.sort(rows, by_created)
  return rows
end
M["comment-author"] = function(c)
  local t_207_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _208_()
      return t_2_auto:get({where = {id = (c.author_id or 0)}})
    end
    ok_3_auto, result_4_auto = pcall(_208_)
    if ok_3_auto then
      t_207_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      t_207_ = error(result_4_auto, 0)
    end
  end
  if (nil ~= t_207_) then
    t_207_ = t_207_[1]
  else
  end
  return t_207_
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
M["delete-session"] = function(session_id)
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
  local ok_3_auto, result_4_auto
  local function _213_()
    return t_2_auto:update({set = {deleted_at = os.time()}, where = {id = (session_id or 0)}})
  end
  ok_3_auto, result_4_auto = pcall(_213_)
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
end
M["create-session"] = function(_3fopts)
  local opts = (_3fopts or {})
  local repo_id = with_repo()
  local db_mod_1_auto = require("codeboomer.singleton")
  local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
  local ok_3_auto, result_4_auto
  local function _215_()
    local function _217_()
      local t_216_ = opts
      if (nil ~= t_216_) then
        t_216_ = t_216_["head-sha"]
      else
      end
      return t_216_
    end
    local function _220_()
      local t_219_ = opts
      if (nil ~= t_219_) then
        t_219_ = t_219_["base-sha"]
      else
      end
      return t_219_
    end
    return t_2_auto:insert({branch = (opts.branch or git["branch-name"]()), head_commit = with_commit(repo_id, _217_()), base_commit = with_commit(repo_id, _220_()), repo_id = repo_id, pr_number = opts["pr-number"]})
  end
  ok_3_auto, result_4_auto = pcall(_215_)
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
end
return M
