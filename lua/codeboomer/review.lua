-- [nfnl] fnl/codeboomer/review.fnl
vim = vim
local git = require("codeboomer.git")
local sqlite = require("codeboomer.sqlite")
local s = require("codeboomer.singleton")
local M = {}
local function debug_log(msg)
  return pcall(vim.fn.writefile, {(os.date("%Y-%m-%d %H:%M:%S") .. " " .. msg)}, (vim.fn.stdpath("data") .. "/codeboomer-debug.log"), "a")
end
local function with_user()
  local email = git["user-email"]()
  local entry_3f
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _1_()
      return t_2_auto:get({where = {email = email}})
    end
    ok_3_auto, result_4_auto = pcall(_1_)
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_3_ = entry_3f
    if (nil ~= t_3_) then
      t_3_ = t_3_[1]
    else
    end
    if (nil ~= t_3_) then
      t_3_ = t_3_.id
    else
    end
    return t_3_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _6_()
      return t_2_auto:insert({name = git["user-name"](), email = email})
    end
    ok_3_auto, result_4_auto = pcall(_6_)
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
    local function _9_()
      return t_2_auto:get({where = {email = "agent@codeboomer"}})
    end
    ok_3_auto, result_4_auto = pcall(_9_)
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_11_ = entry_3f
    if (nil ~= t_11_) then
      t_11_ = t_11_[1]
    else
    end
    if (nil ~= t_11_) then
      t_11_ = t_11_.id
    else
    end
    return t_11_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _14_()
      return t_2_auto:insert({name = "agent", email = "agent@codeboomer"})
    end
    ok_3_auto, result_4_auto = pcall(_14_)
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
    local function _17_()
      return t_2_auto:get({where = {path = repo_path}})
    end
    ok_3_auto, result_4_auto = pcall(_17_)
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_19_ = entry_3f
    if (nil ~= t_19_) then
      t_19_ = t_19_[1]
    else
    end
    if (nil ~= t_19_) then
      t_19_ = t_19_.id
    else
    end
    return t_19_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _22_()
      return t_2_auto:insert({path = repo_path})
    end
    ok_3_auto, result_4_auto = pcall(_22_)
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
      local function _25_()
        return t_2_auto:get({where = {hash = commit_hash}})
      end
      ok_3_auto, result_4_auto = pcall(_25_)
      if ok_3_auto then
        entry_3f = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        entry_3f = error(result_4_auto, 0)
      end
    end
    local _28_
    do
      local t_27_ = entry_3f
      if (nil ~= t_27_) then
        t_27_ = t_27_[1]
      else
      end
      if (nil ~= t_27_) then
        t_27_ = t_27_.id
      else
      end
      _28_ = t_27_
    end
    if _28_ then
      local t_31_ = entry_3f
      if (nil ~= t_31_) then
        t_31_ = t_31_[1]
      else
      end
      if (nil ~= t_31_) then
        t_31_ = t_31_.id
      else
      end
      return t_31_
    else
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _34_()
        return t_2_auto:insert({hash = commit_hash, repo = repo_id})
      end
      ok_3_auto, result_4_auto = pcall(_34_)
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
  local _38_
  if (type(code) == "string") then
    _38_ = code
  else
    _38_ = vim.inspect(code)
  end
  local function _40_()
    if (type(body) == "string") then
      return body
    else
      return vim.inspect(body)
    end
  end
  debug_log(string.format("user-comment session=%s(%s) file=%s(%s) line1=%s(%s) line2=%s(%s) code=%s:%s body=%s:%s", tostring(session_id), type(session_id), tostring(file_path), type(file_path), tostring(line_start), type(line_start), tostring(line_end), type(line_end), type(code), _38_, type(body), _40_()))
  local user_id = with_user()
  local repo_id = with_repo()
  local commit_id = with_commit(repo_id)
  local thread_id
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _41_()
      return t_2_auto:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = code, anchor_commit = commit_id, status = "open", kind = "local", created_by = user_id})
    end
    ok_3_auto, result_4_auto = pcall(_41_)
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
  local function _43_()
    return t_2_auto:insert({thread_id = thread_id, author_id = user_id, body = body, source = "user", commit_id = commit_id})
  end
  ok_3_auto, result_4_auto = pcall(_43_)
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
      local t_46_
      do
        local db_mod_1_auto = require("codeboomer.singleton")
        local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
        local ok_3_auto, result_4_auto
        local function _47_()
          return t_2_auto:get({where = {path = root}})
        end
        ok_3_auto, result_4_auto = pcall(_47_)
        if ok_3_auto then
          t_46_ = result_4_auto
        else
          db_mod_1_auto["reset-db"]()
          t_46_ = error(result_4_auto, 0)
        end
      end
      if (nil ~= t_46_) then
        t_46_ = t_46_[1]
      else
      end
      if (nil ~= t_46_) then
        t_46_ = t_46_.id
      else
      end
      repo_id = t_46_
    end
    if repo_id then
      local sessions
      do
        local tbl_26_ = {}
        local i_27_ = 0
        local _51_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _52_()
            return t_2_auto:get({where = {repo_id = repo_id}})
          end
          ok_3_auto, result_4_auto = pcall(_52_)
          if ok_3_auto then
            _51_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            _51_ = error(result_4_auto, 0)
          end
        end
        for _, row in ipairs(sqlite["active-rows"]((_51_ or {}))) do
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
      local function _56_(a, b)
        return ((a.id or 0) < (b.id or 0))
      end
      table.sort(sessions, _56_)
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
        local t_59_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _60_()
            return t_2_auto:get({where = {path = root}})
          end
          ok_3_auto, result_4_auto = pcall(_60_)
          if ok_3_auto then
            t_59_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            t_59_ = error(result_4_auto, 0)
          end
        end
        if (nil ~= t_59_) then
          t_59_ = t_59_[1]
        else
        end
        if (nil ~= t_59_) then
          t_59_ = t_59_.id
        else
        end
        repo_id = t_59_
      end
      if repo_id then
        local t_64_
        local function _66_()
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _65_()
            return t_2_auto:get({where = {repo_id = repo_id, pr_number = pr_number}})
          end
          ok_3_auto, result_4_auto = pcall(_65_)
          if ok_3_auto then
            return result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            return error(result_4_auto, 0)
          end
        end
        t_64_ = sqlite["active-rows"](_66_())
        if (nil ~= t_64_) then
          t_64_ = t_64_[1]
        else
        end
        return t_64_
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
        local t_72_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _73_()
            return t_2_auto:get({where = {path = root}})
          end
          ok_3_auto, result_4_auto = pcall(_73_)
          if ok_3_auto then
            t_72_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            t_72_ = error(result_4_auto, 0)
          end
        end
        if (nil ~= t_72_) then
          t_72_ = t_72_[1]
        else
        end
        if (nil ~= t_72_) then
          t_72_ = t_72_.id
        else
        end
        repo_id = t_72_
      end
      if repo_id then
        local found = nil
        local _77_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _78_()
            return t_2_auto:get({where = {repo_id = repo_id, branch = branch}})
          end
          ok_3_auto, result_4_auto = pcall(_78_)
          if ok_3_auto then
            _77_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            _77_ = error(result_4_auto, 0)
          end
        end
        for _, row in ipairs(sqlite["active-rows"]((_77_ or {}))) do
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
    local t_84_
    local function _86_()
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _85_()
        return t_2_auto:get({where = {id = id}})
      end
      ok_3_auto, result_4_auto = pcall(_85_)
      if ok_3_auto then
        return result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        return error(result_4_auto, 0)
      end
    end
    t_84_ = sqlite["active-rows"](_86_())
    if (nil ~= t_84_) then
      t_84_ = t_84_[1]
    else
    end
    return t_84_
  else
    return nil
  end
end
M["comment-by-gh"] = function(gh_id)
  if gh_id then
    local t_90_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _91_()
        return t_2_auto:get({where = {gh_comment_id = tostring(gh_id)}})
      end
      ok_3_auto, result_4_auto = pcall(_91_)
      if ok_3_auto then
        t_90_ = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        t_90_ = error(result_4_auto, 0)
      end
    end
    if (nil ~= t_90_) then
      t_90_ = t_90_[1]
    else
    end
    return t_90_
  else
    return nil
  end
end
M["thread-id-for-gh"] = function(gh_id)
  if gh_id then
    local t_95_ = M["comment-by-gh"](gh_id)
    if (nil ~= t_95_) then
      t_95_ = t_95_.thread_id
    else
    end
    return t_95_
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
    local function _98_()
      return t_2_auto:get({where = {email = email}})
    end
    ok_3_auto, result_4_auto = pcall(_98_)
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  local _101_
  do
    local t_100_ = entry_3f
    if (nil ~= t_100_) then
      t_100_ = t_100_[1]
    else
    end
    if (nil ~= t_100_) then
      t_100_ = t_100_.id
    else
    end
    _101_ = t_100_
  end
  if _101_ then
    local t_104_ = entry_3f
    if (nil ~= t_104_) then
      t_104_ = t_104_[1]
    else
    end
    if (nil ~= t_104_) then
      t_104_ = t_104_.id
    else
    end
    return t_104_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _107_()
      return t_2_auto:insert({name = (login or "unknown"), email = email})
    end
    ok_3_auto, result_4_auto = pcall(_107_)
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
    local t_110_ = item
    if (nil ~= t_110_) then
      t_110_ = t_110_.user
    else
    end
    if (nil ~= t_110_) then
      t_110_ = t_110_.login
    else
    end
    login = t_110_
  end
  local line = (item.line or item.original_line or 1)
  local commit_id = with_commit(repo_id, item.commit_id)
  local thread_id
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _113_()
      local _114_
      if not item.position then
        _114_ = 1
      else
        _114_ = nil
      end
      return t_2_auto:insert({session_id = session_id, file_path = item.path, line_start = line, line_end = line, anchor_commit = commit_id, status = "open", kind = "review", gh_outdated = _114_, created_by = M["with-gh-user"](login)})
    end
    ok_3_auto, result_4_auto = pcall(_113_)
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
    local function _117_()
      return t_2_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](login), body = item.body, source = "github", commit_id = commit_id, gh_comment_id = tostring(item.id)})
    end
    ok_3_auto, result_4_auto = pcall(_117_)
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
  local function _119_()
    local function _121_()
      local t_120_ = item
      if (nil ~= t_120_) then
        t_120_ = t_120_.user
      else
      end
      if (nil ~= t_120_) then
        t_120_ = t_120_.login
      else
      end
      return t_120_
    end
    return t_2_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](_121_()), body = item.body, source = "github", commit_id = with_commit(with_repo(), item.commit_id), gh_comment_id = tostring(item.id)})
  end
  ok_3_auto, result_4_auto = pcall(_119_)
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
  local t_127_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _128_()
      return t_2_auto:get({where = {id = (id or 0)}})
    end
    ok_3_auto, result_4_auto = pcall(_128_)
    if ok_3_auto then
      t_127_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      t_127_ = error(result_4_auto, 0)
    end
  end
  if (nil ~= t_127_) then
    t_127_ = t_127_[1]
  else
  end
  return t_127_
end
local function root_of(t)
  local _131_
  if t.parent_id then
    _131_ = thread_by_id(t.parent_id)
  else
    _131_ = nil
  end
  return (_131_ or t)
end
local function twin_of(t)
  local root = root_of(t)
  if ((root.id or 0) == (t.id or 0)) then
    local t_133_
    local function _135_()
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _134_()
        return t_2_auto:get({where = {parent_id = (t.id or 0)}})
      end
      ok_3_auto, result_4_auto = pcall(_134_)
      if ok_3_auto then
        return result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        return error(result_4_auto, 0)
      end
    end
    t_133_ = sqlite["active-rows"](_135_())
    if (nil ~= t_133_) then
      t_133_ = t_133_[1]
    else
    end
    return t_133_
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
    local function _140_()
      if (twin and ((twin.id or 0) ~= (root.id or 0))) then
        return M["comments-for"](twin.id)
      else
        return {}
      end
    end
    rows = vim.list_extend(M["comments-for"]((root.id or 0)), _140_())
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
        local function _142_()
          return t_2_auto:insert({session_id = t.session_id, file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = t.code_snapshot, anchor_commit = t.anchor_commit, status = "open", kind = "local", parent_id = t.id, created_by = with_user()})
        end
        ok_3_auto, result_4_auto = pcall(_142_)
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
  local function _146_(msg, level)
    vim.notify(msg, level)
    return nil
  end
  refuse = _146_
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
      local function _147_()
        return t_2_auto:insert({session_id = (_3fsession_id or t.session_id), file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = t.code_snapshot, anchor_commit = commit_id, status = "open", kind = "review", parent_id = t.id, created_by = with_user()})
      end
      ok_3_auto, result_4_auto = pcall(_147_)
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
      local function _149_()
        return t_2_auto:insert({thread_id = twin_id, author_id = with_user(), body = body, source = "user", commit_id = commit_id})
      end
      ok_3_auto, result_4_auto = pcall(_149_)
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
  local function _152_()
    return t_2_auto:update({set = {body = body}, where = {id = (comment_id or 0)}})
  end
  ok_3_auto, result_4_auto = pcall(_152_)
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
  local function _154_()
    return t_2_auto:update({set = {gh_comment_id = tostring(gh_id)}, where = {id = (comment_id or 0)}})
  end
  ok_3_auto, result_4_auto = pcall(_154_)
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
end
M["agent-reply"] = function(thread_id, body)
  local rows
  local _156_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _157_()
      return t_2_auto:get({where = {id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_157_)
    if ok_3_auto then
      _156_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      _156_ = error(result_4_auto, 0)
    end
  end
  rows = (_156_ or {})
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
      local function _160_()
        return t_2_auto:insert({thread_id = target.id, author_id = with_agent_user(), body = body, source = "agent", commit_id = target.anchor_commit})
      end
      ok_3_auto, result_4_auto = pcall(_160_)
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
  local _164_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _165_()
      return t_2_auto:get({where = {id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_165_)
    if ok_3_auto then
      _164_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      _164_ = error(result_4_auto, 0)
    end
  end
  rows = (_164_ or {})
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
    local function _167_()
      return t_2_auto:insert({thread_id = thread_id, author_id = with_user(), body = body, source = "user", commit_id = thread.anchor_commit})
    end
    ok_3_auto, result_4_auto = pcall(_167_)
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
    local function _170_()
      return t_2_auto:update({set = {status = "resolved"}, where = {id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_170_)
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
    local function _173_()
      return t_2_auto:update({set = {status = "resolved"}, where = {id = twin.id}})
    end
    ok_3_auto, result_4_auto = pcall(_173_)
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
  local t_176_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _177_()
      return t_2_auto:get({where = {id = commit_id}})
    end
    ok_3_auto, result_4_auto = pcall(_177_)
    if ok_3_auto then
      t_176_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      t_176_ = error(result_4_auto, 0)
    end
  end
  if (nil ~= t_176_) then
    t_176_ = t_176_[1]
  else
  end
  if (nil ~= t_176_) then
    t_176_ = t_176_.hash
  else
  end
  return t_176_
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
    local function _187_(d)
      for _, id in ipairs(ids) do
        d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
      end
      return nil
    end
    return s["get-db"]():with_open(_187_)
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
    local _190_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _191_()
        return t_2_auto:get({where = {session_id = session_id}})
      end
      ok_3_auto, result_4_auto = pcall(_191_)
      if ok_3_auto then
        _190_ = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        _190_ = error(result_4_auto, 0)
      end
    end
    rows = unresolved_rows(sqlite["active-rows"]((_190_ or {})))
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
    local _195_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _196_()
        return t_2_auto:get({where = {session_id = session_id, kind = "review"}})
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
    table.sort(rows, by_file_then_line)
    return rows
  end
end
M["comments-for"] = function(thread_id)
  local rows
  local _199_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _200_()
      return t_2_auto:get({where = {thread_id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_200_)
    if ok_3_auto then
      _199_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      _199_ = error(result_4_auto, 0)
    end
  end
  rows = sqlite["active-rows"]((_199_ or {}))
  table.sort(rows, by_created)
  return rows
end
M["comment-author"] = function(c)
  local t_202_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _203_()
      return t_2_auto:get({where = {id = (c.author_id or 0)}})
    end
    ok_3_auto, result_4_auto = pcall(_203_)
    if ok_3_auto then
      t_202_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      t_202_ = error(result_4_auto, 0)
    end
  end
  if (nil ~= t_202_) then
    t_202_ = t_202_[1]
  else
  end
  return t_202_
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
  local function _208_()
    return t_2_auto:update({set = {deleted_at = os.time()}, where = {id = (session_id or 0)}})
  end
  ok_3_auto, result_4_auto = pcall(_208_)
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
  local function _210_()
    local function _212_()
      local t_211_ = opts
      if (nil ~= t_211_) then
        t_211_ = t_211_["head-sha"]
      else
      end
      return t_211_
    end
    local function _215_()
      local t_214_ = opts
      if (nil ~= t_214_) then
        t_214_ = t_214_["base-sha"]
      else
      end
      return t_214_
    end
    return t_2_auto:insert({branch = (opts.branch or git["branch-name"]()), head_commit = with_commit(repo_id, _212_()), base_commit = with_commit(repo_id, _215_()), repo_id = repo_id, pr_number = opts["pr-number"]})
  end
  ok_3_auto, result_4_auto = pcall(_210_)
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
end
return M
