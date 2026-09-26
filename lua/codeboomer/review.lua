-- [nfnl] fnl/codeboomer/review.fnl
vim = vim
local git = require("codeboomer.git")
local sqlite = require("codeboomer.sqlite")
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
    local tgt_3_ = require("codeboomer.config")
    if (tgt_3_)["debug?"](tgt_3_) then
      vim.notify("querying sqlite.user", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_6_ = entry_3f
    if (nil ~= t_6_) then
      t_6_ = t_6_[1]
    else
    end
    if (nil ~= t_6_) then
      t_6_ = t_6_.id
    else
    end
    return t_6_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _9_()
      return t_2_auto:insert({name = git["user-name"](), email = email})
    end
    ok_3_auto, result_4_auto = pcall(_9_)
    local tgt_10_ = require("codeboomer.config")
    if (tgt_10_)["debug?"](tgt_10_) then
      vim.notify("querying sqlite.user", vim.log.levels.INFO)
    else
    end
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
    local function _14_()
      return t_2_auto:get({where = {email = "agent@codeboomer"}})
    end
    ok_3_auto, result_4_auto = pcall(_14_)
    local tgt_15_ = require("codeboomer.config")
    if (tgt_15_)["debug?"](tgt_15_) then
      vim.notify("querying sqlite.user", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_18_ = entry_3f
    if (nil ~= t_18_) then
      t_18_ = t_18_[1]
    else
    end
    if (nil ~= t_18_) then
      t_18_ = t_18_.id
    else
    end
    return t_18_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _21_()
      return t_2_auto:insert({name = "agent", email = "agent@codeboomer"})
    end
    ok_3_auto, result_4_auto = pcall(_21_)
    local tgt_22_ = require("codeboomer.config")
    if (tgt_22_)["debug?"](tgt_22_) then
      vim.notify("querying sqlite.user", vim.log.levels.INFO)
    else
    end
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
    local function _26_()
      return t_2_auto:get({where = {path = repo_path}})
    end
    ok_3_auto, result_4_auto = pcall(_26_)
    local tgt_27_ = require("codeboomer.config")
    if (tgt_27_)["debug?"](tgt_27_) then
      vim.notify("querying sqlite.repo", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_30_ = entry_3f
    if (nil ~= t_30_) then
      t_30_ = t_30_[1]
    else
    end
    if (nil ~= t_30_) then
      t_30_ = t_30_.id
    else
    end
    return t_30_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _33_()
      return t_2_auto:insert({path = repo_path})
    end
    ok_3_auto, result_4_auto = pcall(_33_)
    local tgt_34_ = require("codeboomer.config")
    if (tgt_34_)["debug?"](tgt_34_) then
      vim.notify("querying sqlite.repo", vim.log.levels.INFO)
    else
    end
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
      local function _38_()
        return t_2_auto:get({where = {hash = commit_hash}})
      end
      ok_3_auto, result_4_auto = pcall(_38_)
      local tgt_39_ = require("codeboomer.config")
      if (tgt_39_)["debug?"](tgt_39_) then
        vim.notify("querying sqlite.commit", vim.log.levels.INFO)
      else
      end
      if ok_3_auto then
        entry_3f = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        entry_3f = error(result_4_auto, 0)
      end
    end
    local _43_
    do
      local t_42_ = entry_3f
      if (nil ~= t_42_) then
        t_42_ = t_42_[1]
      else
      end
      if (nil ~= t_42_) then
        t_42_ = t_42_.id
      else
      end
      _43_ = t_42_
    end
    if _43_ then
      local t_46_ = entry_3f
      if (nil ~= t_46_) then
        t_46_ = t_46_[1]
      else
      end
      if (nil ~= t_46_) then
        t_46_ = t_46_.id
      else
      end
      return t_46_
    else
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _49_()
        return t_2_auto:insert({hash = commit_hash, repo = repo_id})
      end
      ok_3_auto, result_4_auto = pcall(_49_)
      local tgt_50_ = require("codeboomer.config")
      if (tgt_50_)["debug?"](tgt_50_) then
        vim.notify("querying sqlite.commit", vim.log.levels.INFO)
      else
      end
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
    local function _55_()
      return t_2_auto:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = sql_literal(code), anchor_commit = commit_id, status = "open", type = "line", kind = "local", created_by = user_id})
    end
    ok_3_auto, result_4_auto = pcall(_55_)
    local tgt_56_ = require("codeboomer.config")
    if (tgt_56_)["debug?"](tgt_56_) then
      vim.notify("querying sqlite.thread", vim.log.levels.INFO)
    else
    end
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
  local function _59_()
    return t_2_auto:insert({thread_id = thread_id, author_id = user_id, body = sql_literal(body), source = "user", commit_id = commit_id})
  end
  ok_3_auto, result_4_auto = pcall(_59_)
  local tgt_60_ = require("codeboomer.config")
  if (tgt_60_)["debug?"](tgt_60_) then
    vim.notify("querying sqlite.comments", vim.log.levels.INFO)
  else
  end
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
    local function _63_()
      return t_2_auto:insert({session_id = session_id, file_path = file_path, anchor_commit = commit_id, status = "open", type = "file", kind = "local", created_by = user_id})
    end
    ok_3_auto, result_4_auto = pcall(_63_)
    local tgt_64_ = require("codeboomer.config")
    if (tgt_64_)["debug?"](tgt_64_) then
      vim.notify("querying sqlite.thread", vim.log.levels.INFO)
    else
    end
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
  local function _67_()
    return t_2_auto:insert({thread_id = thread_id, author_id = user_id, body = sql_literal(body), source = "user", commit_id = commit_id})
  end
  ok_3_auto, result_4_auto = pcall(_67_)
  local tgt_68_ = require("codeboomer.config")
  if (tgt_68_)["debug?"](tgt_68_) then
    vim.notify("querying sqlite.comments", vim.log.levels.INFO)
  else
  end
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
      local t_72_
      do
        local db_mod_1_auto = require("codeboomer.singleton")
        local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
        local ok_3_auto, result_4_auto
        local function _73_()
          return t_2_auto:get({where = {path = root}})
        end
        ok_3_auto, result_4_auto = pcall(_73_)
        local tgt_74_ = require("codeboomer.config")
        if (tgt_74_)["debug?"](tgt_74_) then
          vim.notify("querying sqlite.repo", vim.log.levels.INFO)
        else
        end
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
      local sessions
      do
        local tbl_26_ = {}
        local i_27_ = 0
        local _79_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _80_()
            return t_2_auto:get({where = {repo_id = repo_id}})
          end
          ok_3_auto, result_4_auto = pcall(_80_)
          local tgt_81_ = require("codeboomer.config")
          if (tgt_81_)["debug?"](tgt_81_) then
            vim.notify("querying sqlite.session", vim.log.levels.INFO)
          else
          end
          if ok_3_auto then
            _79_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            _79_ = error(result_4_auto, 0)
          end
        end
        for _, row in ipairs(sqlite["active-rows"]((_79_ or {}))) do
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
      local function _86_(a, b)
        return ((a.id or 0) < (b.id or 0))
      end
      table.sort(sessions, _86_)
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
        local t_89_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _90_()
            return t_2_auto:get({where = {path = root}})
          end
          ok_3_auto, result_4_auto = pcall(_90_)
          local tgt_91_ = require("codeboomer.config")
          if (tgt_91_)["debug?"](tgt_91_) then
            vim.notify("querying sqlite.repo", vim.log.levels.INFO)
          else
          end
          if ok_3_auto then
            t_89_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            t_89_ = error(result_4_auto, 0)
          end
        end
        if (nil ~= t_89_) then
          t_89_ = t_89_[1]
        else
        end
        if (nil ~= t_89_) then
          t_89_ = t_89_.id
        else
        end
        repo_id = t_89_
      end
      if repo_id then
        local t_96_
        local function _98_()
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _97_()
            return t_2_auto:get({where = {repo_id = repo_id, pr_number = pr_number}})
          end
          ok_3_auto, result_4_auto = pcall(_97_)
          local tgt_99_ = require("codeboomer.config")
          if (tgt_99_)["debug?"](tgt_99_) then
            vim.notify("querying sqlite.session", vim.log.levels.INFO)
          else
          end
          if ok_3_auto then
            return result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            return error(result_4_auto, 0)
          end
        end
        t_96_ = sqlite["active-rows"](_98_())
        if (nil ~= t_96_) then
          t_96_ = t_96_[1]
        else
        end
        return t_96_
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
        local t_106_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.repo(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _107_()
            return t_2_auto:get({where = {path = root}})
          end
          ok_3_auto, result_4_auto = pcall(_107_)
          local tgt_108_ = require("codeboomer.config")
          if (tgt_108_)["debug?"](tgt_108_) then
            vim.notify("querying sqlite.repo", vim.log.levels.INFO)
          else
          end
          if ok_3_auto then
            t_106_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            t_106_ = error(result_4_auto, 0)
          end
        end
        if (nil ~= t_106_) then
          t_106_ = t_106_[1]
        else
        end
        if (nil ~= t_106_) then
          t_106_ = t_106_.id
        else
        end
        repo_id = t_106_
      end
      if repo_id then
        local found = nil
        local _113_
        do
          local db_mod_1_auto = require("codeboomer.singleton")
          local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
          local ok_3_auto, result_4_auto
          local function _114_()
            return t_2_auto:get({where = {repo_id = repo_id, branch = branch}})
          end
          ok_3_auto, result_4_auto = pcall(_114_)
          local tgt_115_ = require("codeboomer.config")
          if (tgt_115_)["debug?"](tgt_115_) then
            vim.notify("querying sqlite.session", vim.log.levels.INFO)
          else
          end
          if ok_3_auto then
            _113_ = result_4_auto
          else
            db_mod_1_auto["reset-db"]()
            _113_ = error(result_4_auto, 0)
          end
        end
        for _, row in ipairs(sqlite["active-rows"]((_113_ or {}))) do
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
    local t_122_
    local function _124_()
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.session(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _123_()
        return t_2_auto:get({where = {id = id}})
      end
      ok_3_auto, result_4_auto = pcall(_123_)
      local tgt_125_ = require("codeboomer.config")
      if (tgt_125_)["debug?"](tgt_125_) then
        vim.notify("querying sqlite.session", vim.log.levels.INFO)
      else
      end
      if ok_3_auto then
        return result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        return error(result_4_auto, 0)
      end
    end
    t_122_ = sqlite["active-rows"](_124_())
    if (nil ~= t_122_) then
      t_122_ = t_122_[1]
    else
    end
    return t_122_
  else
    return nil
  end
end
M["comment-by-gh"] = function(gh_id)
  if gh_id then
    local t_130_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _131_()
        return t_2_auto:get({where = {gh_comment_id = tostring(gh_id)}})
      end
      ok_3_auto, result_4_auto = pcall(_131_)
      local tgt_132_ = require("codeboomer.config")
      if (tgt_132_)["debug?"](tgt_132_) then
        vim.notify("querying sqlite.comments", vim.log.levels.INFO)
      else
      end
      if ok_3_auto then
        t_130_ = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        t_130_ = error(result_4_auto, 0)
      end
    end
    if (nil ~= t_130_) then
      t_130_ = t_130_[1]
    else
    end
    return t_130_
  else
    return nil
  end
end
M["thread-id-for-gh"] = function(gh_id)
  if gh_id then
    local t_137_ = M["comment-by-gh"](gh_id)
    if (nil ~= t_137_) then
      t_137_ = t_137_.thread_id
    else
    end
    return t_137_
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
    local function _140_()
      return t_2_auto:get({where = {email = email}})
    end
    ok_3_auto, result_4_auto = pcall(_140_)
    local tgt_141_ = require("codeboomer.config")
    if (tgt_141_)["debug?"](tgt_141_) then
      vim.notify("querying sqlite.user", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      entry_3f = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      entry_3f = error(result_4_auto, 0)
    end
  end
  local _145_
  do
    local t_144_ = entry_3f
    if (nil ~= t_144_) then
      t_144_ = t_144_[1]
    else
    end
    if (nil ~= t_144_) then
      t_144_ = t_144_.id
    else
    end
    _145_ = t_144_
  end
  if _145_ then
    local t_148_ = entry_3f
    if (nil ~= t_148_) then
      t_148_ = t_148_[1]
    else
    end
    if (nil ~= t_148_) then
      t_148_ = t_148_.id
    else
    end
    return t_148_
  else
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _151_()
      return t_2_auto:insert({name = (login or "unknown"), email = email})
    end
    ok_3_auto, result_4_auto = pcall(_151_)
    local tgt_152_ = require("codeboomer.config")
    if (tgt_152_)["debug?"](tgt_152_) then
      vim.notify("querying sqlite.user", vim.log.levels.INFO)
    else
    end
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
    local t_156_ = item
    if (nil ~= t_156_) then
      t_156_ = t_156_.user
    else
    end
    if (nil ~= t_156_) then
      t_156_ = t_156_.login
    else
    end
    login = t_156_
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
    local function _160_()
      local _161_
      if file_3f then
        _161_ = "file"
      else
        _161_ = "line"
      end
      local _163_
      if (not file_3f and not item.position) then
        _163_ = 1
      else
        _163_ = nil
      end
      return t_2_auto:insert({session_id = session_id, file_path = item.path, line_start = line, line_end = line, anchor_commit = commit_id, status = "open", type = _161_, kind = "review", gh_outdated = _163_, created_by = M["with-gh-user"](login)})
    end
    ok_3_auto, result_4_auto = pcall(_160_)
    local tgt_165_ = require("codeboomer.config")
    if (tgt_165_)["debug?"](tgt_165_) then
      vim.notify("querying sqlite.thread", vim.log.levels.INFO)
    else
    end
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
    local function _168_()
      return t_2_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](login), body = sql_literal(item.body), source = "github", commit_id = commit_id, gh_comment_id = tostring(item.id)})
    end
    ok_3_auto, result_4_auto = pcall(_168_)
    local tgt_169_ = require("codeboomer.config")
    if (tgt_169_)["debug?"](tgt_169_) then
      vim.notify("querying sqlite.comments", vim.log.levels.INFO)
    else
    end
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
  local function _172_()
    local function _174_()
      local t_173_ = item
      if (nil ~= t_173_) then
        t_173_ = t_173_.user
      else
      end
      if (nil ~= t_173_) then
        t_173_ = t_173_.login
      else
      end
      return t_173_
    end
    return t_2_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](_174_()), body = sql_literal(item.body), source = "github", commit_id = with_commit(with_repo(), item.commit_id), gh_comment_id = tostring(item.id)})
  end
  ok_3_auto, result_4_auto = pcall(_172_)
  local tgt_177_ = require("codeboomer.config")
  if (tgt_177_)["debug?"](tgt_177_) then
    vim.notify("querying sqlite.comments", vim.log.levels.INFO)
  else
  end
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
  local t_182_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _183_()
      return t_2_auto:get({where = {id = (id or 0)}})
    end
    ok_3_auto, result_4_auto = pcall(_183_)
    local tgt_184_ = require("codeboomer.config")
    if (tgt_184_)["debug?"](tgt_184_) then
      vim.notify("querying sqlite.thread", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      t_182_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      t_182_ = error(result_4_auto, 0)
    end
  end
  if (nil ~= t_182_) then
    t_182_ = t_182_[1]
  else
  end
  return t_182_
end
local function root_of(t)
  local _188_
  if t.parent_id then
    _188_ = thread_by_id(t.parent_id)
  else
    _188_ = nil
  end
  return (_188_ or t)
end
local function twin_of(t)
  local root = root_of(t)
  if ((root.id or 0) == (t.id or 0)) then
    local t_190_
    local function _192_()
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _191_()
        return t_2_auto:get({where = {parent_id = (t.id or 0)}})
      end
      ok_3_auto, result_4_auto = pcall(_191_)
      local tgt_193_ = require("codeboomer.config")
      if (tgt_193_)["debug?"](tgt_193_) then
        vim.notify("querying sqlite.thread", vim.log.levels.INFO)
      else
      end
      if ok_3_auto then
        return result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        return error(result_4_auto, 0)
      end
    end
    t_190_ = sqlite["active-rows"](_192_())
    if (nil ~= t_190_) then
      t_190_ = t_190_[1]
    else
    end
    return t_190_
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
    local function _199_()
      if (twin and ((twin.id or 0) ~= (root.id or 0))) then
        return M["comments-for"](twin.id)
      else
        return {}
      end
    end
    rows = vim.list_extend(M["comments-for"]((root.id or 0)), _199_())
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
        local function _201_()
          return t_2_auto:insert({session_id = t.session_id, file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = t.anchor_commit, status = "open", type = (t.type or "line"), kind = "local", parent_id = t.id, created_by = with_user()})
        end
        ok_3_auto, result_4_auto = pcall(_201_)
        local tgt_202_ = require("codeboomer.config")
        if (tgt_202_)["debug?"](tgt_202_) then
          vim.notify("querying sqlite.thread", vim.log.levels.INFO)
        else
        end
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
  local function _207_(msg, level)
    vim.notify(msg, level)
    return nil
  end
  refuse = _207_
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
      local function _208_()
        return t_2_auto:insert({session_id = (_3fsession_id or t.session_id), file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = commit_id, status = "open", type = (t.type or "line"), kind = "review", parent_id = t.id, created_by = with_user()})
      end
      ok_3_auto, result_4_auto = pcall(_208_)
      local tgt_209_ = require("codeboomer.config")
      if (tgt_209_)["debug?"](tgt_209_) then
        vim.notify("querying sqlite.thread", vim.log.levels.INFO)
      else
      end
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
      local function _212_()
        return t_2_auto:insert({thread_id = twin_id, author_id = with_user(), body = sql_literal(body), source = "user", commit_id = commit_id})
      end
      ok_3_auto, result_4_auto = pcall(_212_)
      local tgt_213_ = require("codeboomer.config")
      if (tgt_213_)["debug?"](tgt_213_) then
        vim.notify("querying sqlite.comments", vim.log.levels.INFO)
      else
      end
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
  local function _217_()
    return t_2_auto:update({set = {body = sql_literal(body)}, where = {id = (comment_id or 0)}})
  end
  ok_3_auto, result_4_auto = pcall(_217_)
  local tgt_218_ = require("codeboomer.config")
  if (tgt_218_)["debug?"](tgt_218_) then
    vim.notify("querying sqlite.comments", vim.log.levels.INFO)
  else
  end
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
  local function _221_()
    return t_2_auto:update({set = {gh_comment_id = tostring(gh_id)}, where = {id = (comment_id or 0)}})
  end
  ok_3_auto, result_4_auto = pcall(_221_)
  local tgt_222_ = require("codeboomer.config")
  if (tgt_222_)["debug?"](tgt_222_) then
    vim.notify("querying sqlite.comments", vim.log.levels.INFO)
  else
  end
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
end
M["agent-reply"] = function(thread_id, body)
  local rows
  local _225_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _226_()
      return t_2_auto:get({where = {id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_226_)
    local tgt_227_ = require("codeboomer.config")
    if (tgt_227_)["debug?"](tgt_227_) then
      vim.notify("querying sqlite.thread", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      _225_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      _225_ = error(result_4_auto, 0)
    end
  end
  rows = (_225_ or {})
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
      local function _231_()
        return t_2_auto:insert({thread_id = target.id, author_id = with_agent_user(), body = sql_literal(body), source = "agent", commit_id = target.anchor_commit})
      end
      ok_3_auto, result_4_auto = pcall(_231_)
      local tgt_232_ = require("codeboomer.config")
      if (tgt_232_)["debug?"](tgt_232_) then
        vim.notify("querying sqlite.comments", vim.log.levels.INFO)
      else
      end
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
  local _237_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _238_()
      return t_2_auto:get({where = {id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_238_)
    local tgt_239_ = require("codeboomer.config")
    if (tgt_239_)["debug?"](tgt_239_) then
      vim.notify("querying sqlite.thread", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      _237_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      _237_ = error(result_4_auto, 0)
    end
  end
  rows = (_237_ or {})
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
    local function _242_()
      return t_2_auto:insert({thread_id = thread_id, author_id = with_user(), body = sql_literal(body), source = "user", commit_id = thread.anchor_commit})
    end
    ok_3_auto, result_4_auto = pcall(_242_)
    local tgt_243_ = require("codeboomer.config")
    if (tgt_243_)["debug?"](tgt_243_) then
      vim.notify("querying sqlite.comments", vim.log.levels.INFO)
    else
    end
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
    local function _247_()
      return t_2_auto:update({set = {status = "resolved"}, where = {id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_247_)
    local tgt_248_ = require("codeboomer.config")
    if (tgt_248_)["debug?"](tgt_248_) then
      vim.notify("querying sqlite.thread", vim.log.levels.INFO)
    else
    end
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
    local function _252_()
      return t_2_auto:update({set = {status = "resolved"}, where = {id = twin.id}})
    end
    ok_3_auto, result_4_auto = pcall(_252_)
    local tgt_253_ = require("codeboomer.config")
    if (tgt_253_)["debug?"](tgt_253_) then
      vim.notify("querying sqlite.thread", vim.log.levels.INFO)
    else
    end
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
  local t_257_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.commit(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _258_()
      return t_2_auto:get({where = {id = commit_id}})
    end
    ok_3_auto, result_4_auto = pcall(_258_)
    local tgt_259_ = require("codeboomer.config")
    if (tgt_259_)["debug?"](tgt_259_) then
      vim.notify("querying sqlite.commit", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      t_257_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      t_257_ = error(result_4_auto, 0)
    end
  end
  if (nil ~= t_257_) then
    t_257_ = t_257_[1]
  else
  end
  if (nil ~= t_257_) then
    t_257_ = t_257_.hash
  else
  end
  return t_257_
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
    local db_mod_5_auto = require("codeboomer.singleton")
    local ok_6_auto, result_7_auto
    local function _270_()
      local function _271_(d)
        for _, id in ipairs(ids) do
          d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
        end
        return nil
      end
      return db_mod_5_auto["get-db"]():with_open(_271_)
    end
    ok_6_auto, result_7_auto = pcall(_270_)
    local tgt_272_ = require("codeboomer.config")
    if (tgt_272_)["debug?"](tgt_272_) then
      vim.notify("opening connection to sqlite", vim.log.levels.INFO)
    else
    end
    if ok_6_auto then
      return result_7_auto
    else
      db_mod_5_auto["reset-db"]()
      return error(result_7_auto, 0)
    end
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
    local _277_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _278_()
        return t_2_auto:get({where = {session_id = session_id}})
      end
      ok_3_auto, result_4_auto = pcall(_278_)
      local tgt_279_ = require("codeboomer.config")
      if (tgt_279_)["debug?"](tgt_279_) then
        vim.notify("querying sqlite.thread", vim.log.levels.INFO)
      else
      end
      if ok_3_auto then
        _277_ = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        _277_ = error(result_4_auto, 0)
      end
    end
    rows = unresolved_rows(sqlite["active-rows"]((_277_ or {})))
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
    local _284_
    do
      local db_mod_1_auto = require("codeboomer.singleton")
      local t_2_auto = sqlite.thread(db_mod_1_auto["get-db"]())
      local ok_3_auto, result_4_auto
      local function _285_()
        return t_2_auto:get({where = {session_id = session_id, kind = "review"}})
      end
      ok_3_auto, result_4_auto = pcall(_285_)
      local tgt_286_ = require("codeboomer.config")
      if (tgt_286_)["debug?"](tgt_286_) then
        vim.notify("querying sqlite.thread", vim.log.levels.INFO)
      else
      end
      if ok_3_auto then
        _284_ = result_4_auto
      else
        db_mod_1_auto["reset-db"]()
        _284_ = error(result_4_auto, 0)
      end
    end
    rows = unresolved_rows(sqlite["active-rows"]((_284_ or {})))
    table.sort(rows, by_file_then_line)
    return rows
  end
end
M["comments-for"] = function(thread_id)
  local rows
  local _290_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.comments(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _291_()
      return t_2_auto:get({where = {thread_id = thread_id}})
    end
    ok_3_auto, result_4_auto = pcall(_291_)
    local tgt_292_ = require("codeboomer.config")
    if (tgt_292_)["debug?"](tgt_292_) then
      vim.notify("querying sqlite.comments", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      _290_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      _290_ = error(result_4_auto, 0)
    end
  end
  rows = sqlite["active-rows"]((_290_ or {}))
  table.sort(rows, by_created)
  return rows
end
M["comment-author"] = function(c)
  local t_295_
  do
    local db_mod_1_auto = require("codeboomer.singleton")
    local t_2_auto = sqlite.user(db_mod_1_auto["get-db"]())
    local ok_3_auto, result_4_auto
    local function _296_()
      return t_2_auto:get({where = {id = (c.author_id or 0)}})
    end
    ok_3_auto, result_4_auto = pcall(_296_)
    local tgt_297_ = require("codeboomer.config")
    if (tgt_297_)["debug?"](tgt_297_) then
      vim.notify("querying sqlite.user", vim.log.levels.INFO)
    else
    end
    if ok_3_auto then
      t_295_ = result_4_auto
    else
      db_mod_1_auto["reset-db"]()
      t_295_ = error(result_4_auto, 0)
    end
  end
  if (nil ~= t_295_) then
    t_295_ = t_295_[1]
  else
  end
  return t_295_
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
  local function _303_()
    return t_2_auto:update({set = {deleted_at = os.time()}, where = {id = (session_id or 0)}})
  end
  ok_3_auto, result_4_auto = pcall(_303_)
  local tgt_304_ = require("codeboomer.config")
  if (tgt_304_)["debug?"](tgt_304_) then
    vim.notify("querying sqlite.session", vim.log.levels.INFO)
  else
  end
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
  local function _307_()
    local function _309_()
      local t_308_ = opts
      if (nil ~= t_308_) then
        t_308_ = t_308_["head-sha"]
      else
      end
      return t_308_
    end
    local function _312_()
      local t_311_ = opts
      if (nil ~= t_311_) then
        t_311_ = t_311_["base-sha"]
      else
      end
      return t_311_
    end
    return t_2_auto:insert({branch = (opts.branch or git["branch-name"]()), head_commit = with_commit(repo_id, _309_()), base_commit = with_commit(repo_id, _312_()), repo_id = repo_id, pr_number = opts["pr-number"]})
  end
  ok_3_auto, result_4_auto = pcall(_307_)
  local tgt_314_ = require("codeboomer.config")
  if (tgt_314_)["debug?"](tgt_314_) then
    vim.notify("querying sqlite.session", vim.log.levels.INFO)
  else
  end
  if ok_3_auto then
    return result_4_auto
  else
    db_mod_1_auto["reset-db"]()
    return error(result_4_auto, 0)
  end
end
return M
