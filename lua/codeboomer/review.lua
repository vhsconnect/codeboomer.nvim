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
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _2_()
      return t_5_auto:get({where = {email = email}})
    end
    ok_6_auto, result_7_auto = pcall(_2_)
    local tgt_3_ = require("codeboomer.config")
    if (tgt_3_)["debug?"](tgt_3_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.user"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.user"] = (1 + (st_2_auto.queries["sqlite.user"] or 0))
      local function _5_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _5_)
    else
    end
    if ok_6_auto then
      entry_3f = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      entry_3f = error(result_7_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_8_ = entry_3f
    if (nil ~= t_8_) then
      t_8_ = t_8_[1]
    else
    end
    if (nil ~= t_8_) then
      t_8_ = t_8_.id
    else
    end
    return t_8_
  else
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _11_()
      return t_5_auto:insert({name = git["user-name"](), email = email})
    end
    ok_6_auto, result_7_auto = pcall(_11_)
    local tgt_12_ = require("codeboomer.config")
    if (tgt_12_)["debug?"](tgt_12_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.user"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.user"] = (1 + (st_2_auto.queries["sqlite.user"] or 0))
      local function _14_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _14_)
    else
    end
    if ok_6_auto then
      return result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      return error(result_7_auto, 0)
    end
  end
end
local function with_agent_user()
  local entry_3f
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _18_()
      return t_5_auto:get({where = {email = "agent@codeboomer"}})
    end
    ok_6_auto, result_7_auto = pcall(_18_)
    local tgt_19_ = require("codeboomer.config")
    if (tgt_19_)["debug?"](tgt_19_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.user"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.user"] = (1 + (st_2_auto.queries["sqlite.user"] or 0))
      local function _21_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _21_)
    else
    end
    if ok_6_auto then
      entry_3f = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      entry_3f = error(result_7_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_24_ = entry_3f
    if (nil ~= t_24_) then
      t_24_ = t_24_[1]
    else
    end
    if (nil ~= t_24_) then
      t_24_ = t_24_.id
    else
    end
    return t_24_
  else
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _27_()
      return t_5_auto:insert({name = "agent", email = "agent@codeboomer"})
    end
    ok_6_auto, result_7_auto = pcall(_27_)
    local tgt_28_ = require("codeboomer.config")
    if (tgt_28_)["debug?"](tgt_28_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.user"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.user"] = (1 + (st_2_auto.queries["sqlite.user"] or 0))
      local function _30_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _30_)
    else
    end
    if ok_6_auto then
      return result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      return error(result_7_auto, 0)
    end
  end
end
local function with_repo()
  local repo_path = git["repo-root"]()
  local entry_3f
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.repo(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _34_()
      return t_5_auto:get({where = {path = repo_path}})
    end
    ok_6_auto, result_7_auto = pcall(_34_)
    local tgt_35_ = require("codeboomer.config")
    if (tgt_35_)["debug?"](tgt_35_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.repo"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.repo"] = (1 + (st_2_auto.queries["sqlite.repo"] or 0))
      local function _37_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.repo"]) .. " " .. "sqlite.repo"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.repo"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.repo"] = vim_1_auto.fn.timer_start(1000, _37_)
    else
    end
    if ok_6_auto then
      entry_3f = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      entry_3f = error(result_7_auto, 0)
    end
  end
  if entry_3f[1] then
    local t_40_ = entry_3f
    if (nil ~= t_40_) then
      t_40_ = t_40_[1]
    else
    end
    if (nil ~= t_40_) then
      t_40_ = t_40_.id
    else
    end
    return t_40_
  else
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.repo(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _43_()
      return t_5_auto:insert({path = repo_path})
    end
    ok_6_auto, result_7_auto = pcall(_43_)
    local tgt_44_ = require("codeboomer.config")
    if (tgt_44_)["debug?"](tgt_44_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.repo"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.repo"] = (1 + (st_2_auto.queries["sqlite.repo"] or 0))
      local function _46_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.repo"]) .. " " .. "sqlite.repo"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.repo"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.repo"] = vim_1_auto.fn.timer_start(1000, _46_)
    else
    end
    if ok_6_auto then
      return result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      return error(result_7_auto, 0)
    end
  end
end
local function with_commit(repo_id, _3fsha)
  local commit_hash = (_3fsha or git["head-sha"]())
  if commit_hash then
    local entry_3f
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.commit(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _50_()
        return t_5_auto:get({where = {hash = commit_hash}})
      end
      ok_6_auto, result_7_auto = pcall(_50_)
      local tgt_51_ = require("codeboomer.config")
      if (tgt_51_)["debug?"](tgt_51_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.commit"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.commit"] = (1 + (st_2_auto.queries["sqlite.commit"] or 0))
        local function _53_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.commit"]) .. " " .. "sqlite.commit"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.commit"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.commit"] = vim_1_auto.fn.timer_start(1000, _53_)
      else
      end
      if ok_6_auto then
        entry_3f = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        entry_3f = error(result_7_auto, 0)
      end
    end
    local _57_
    do
      local t_56_ = entry_3f
      if (nil ~= t_56_) then
        t_56_ = t_56_[1]
      else
      end
      if (nil ~= t_56_) then
        t_56_ = t_56_.id
      else
      end
      _57_ = t_56_
    end
    if _57_ then
      local t_60_ = entry_3f
      if (nil ~= t_60_) then
        t_60_ = t_60_[1]
      else
      end
      if (nil ~= t_60_) then
        t_60_ = t_60_.id
      else
      end
      return t_60_
    else
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.commit(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _63_()
        return t_5_auto:insert({hash = commit_hash, repo = repo_id})
      end
      ok_6_auto, result_7_auto = pcall(_63_)
      local tgt_64_ = require("codeboomer.config")
      if (tgt_64_)["debug?"](tgt_64_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.commit"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.commit"] = (1 + (st_2_auto.queries["sqlite.commit"] or 0))
        local function _66_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.commit"]) .. " " .. "sqlite.commit"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.commit"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.commit"] = vim_1_auto.fn.timer_start(1000, _66_)
      else
      end
      if ok_6_auto then
        return result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        return error(result_7_auto, 0)
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
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _71_()
      return t_5_auto:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = sql_literal(code), anchor_commit = commit_id, status = "open", type = "line", kind = "local", created_by = user_id})
    end
    ok_6_auto, result_7_auto = pcall(_71_)
    local tgt_72_ = require("codeboomer.config")
    if (tgt_72_)["debug?"](tgt_72_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
      local function _74_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _74_)
    else
    end
    if ok_6_auto then
      thread_id = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      thread_id = error(result_7_auto, 0)
    end
  end
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _77_()
    return t_5_auto:insert({thread_id = thread_id, author_id = user_id, body = sql_literal(body), source = "user", commit_id = commit_id})
  end
  ok_6_auto, result_7_auto = pcall(_77_)
  local tgt_78_ = require("codeboomer.config")
  if (tgt_78_)["debug?"](tgt_78_) then
    local vim_1_auto = _G.vim
    local st_2_auto = require("codeboomer.state")
    do
      local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
      if old_timer_3_auto then
        vim_1_auto.fn.timer_stop(old_timer_3_auto)
      else
      end
    end
    st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
    local function _80_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _80_)
  else
  end
  if ok_6_auto then
    return result_7_auto
  else
    db_mod_4_auto["reset-db"]()
    return error(result_7_auto, 0)
  end
end
M["file-comment"] = function(session_id, file_path, body)
  local user_id = with_user()
  local repo_id = with_repo()
  local commit_id = with_commit(repo_id)
  local thread_id
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _83_()
      return t_5_auto:insert({session_id = session_id, file_path = file_path, anchor_commit = commit_id, status = "open", type = "file", kind = "local", created_by = user_id})
    end
    ok_6_auto, result_7_auto = pcall(_83_)
    local tgt_84_ = require("codeboomer.config")
    if (tgt_84_)["debug?"](tgt_84_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
      local function _86_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _86_)
    else
    end
    if ok_6_auto then
      thread_id = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      thread_id = error(result_7_auto, 0)
    end
  end
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _89_()
    return t_5_auto:insert({thread_id = thread_id, author_id = user_id, body = sql_literal(body), source = "user", commit_id = commit_id})
  end
  ok_6_auto, result_7_auto = pcall(_89_)
  local tgt_90_ = require("codeboomer.config")
  if (tgt_90_)["debug?"](tgt_90_) then
    local vim_1_auto = _G.vim
    local st_2_auto = require("codeboomer.state")
    do
      local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
      if old_timer_3_auto then
        vim_1_auto.fn.timer_stop(old_timer_3_auto)
      else
      end
    end
    st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
    local function _92_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _92_)
  else
  end
  if ok_6_auto then
    return result_7_auto
  else
    db_mod_4_auto["reset-db"]()
    return error(result_7_auto, 0)
  end
end
local function repo_id_of(root)
  local t_95_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.repo(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _96_()
      return t_5_auto:get({where = {path = root}})
    end
    ok_6_auto, result_7_auto = pcall(_96_)
    local tgt_97_ = require("codeboomer.config")
    if (tgt_97_)["debug?"](tgt_97_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.repo"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.repo"] = (1 + (st_2_auto.queries["sqlite.repo"] or 0))
      local function _99_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.repo"]) .. " " .. "sqlite.repo"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.repo"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.repo"] = vim_1_auto.fn.timer_start(1000, _99_)
    else
    end
    if ok_6_auto then
      t_95_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_95_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_95_) then
    t_95_ = t_95_[1]
  else
  end
  if (nil ~= t_95_) then
    t_95_ = t_95_.id
  else
  end
  return t_95_
end
M["session-for"] = function(_3fpath)
  local root = git["repo-root"](_3fpath)
  local branch
  if root then
    branch = git["branch-name"](_3fpath)
  else
    branch = nil
  end
  if (root and branch) then
    local repo_id = repo_id_of(root)
    if repo_id then
      local t_105_
      local function _107_()
        local db_mod_4_auto = require("codeboomer.singleton")
        local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
        local ok_6_auto, result_7_auto
        local function _106_()
          return t_5_auto:get({where = {repo_id = repo_id, branch = branch}})
        end
        ok_6_auto, result_7_auto = pcall(_106_)
        local tgt_108_ = require("codeboomer.config")
        if (tgt_108_)["debug?"](tgt_108_) then
          local vim_1_auto = _G.vim
          local st_2_auto = require("codeboomer.state")
          do
            local old_timer_3_auto = st_2_auto.timers["sqlite.session"]
            if old_timer_3_auto then
              vim_1_auto.fn.timer_stop(old_timer_3_auto)
            else
            end
          end
          st_2_auto.queries["sqlite.session"] = (1 + (st_2_auto.queries["sqlite.session"] or 0))
          local function _110_()
            vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
            st_2_auto.queries["sqlite.session"] = nil
            return nil
          end
          st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _110_)
        else
        end
        if ok_6_auto then
          return result_7_auto
        else
          db_mod_4_auto["reset-db"]()
          return error(result_7_auto, 0)
        end
      end
      t_105_ = sqlite["active-rows"](_107_())
      if (nil ~= t_105_) then
        t_105_ = t_105_[1]
      else
      end
      return t_105_
    else
      return nil
    end
  else
    return nil
  end
end
M["current-session-id"] = function()
  local t_116_ = M["session-for"]()
  if (nil ~= t_116_) then
    t_116_ = t_116_.id
  else
  end
  return t_116_
end
M["ensure-session"] = function()
  return (M["current-session-id"]() or M["create-session"]())
end
M["set-session-pr"] = function(session_id, pr_number)
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _118_()
    return t_5_auto:update({set = {pr_number = pr_number}, where = {id = (session_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_118_)
  local tgt_119_ = require("codeboomer.config")
  if (tgt_119_)["debug?"](tgt_119_) then
    local vim_1_auto = _G.vim
    local st_2_auto = require("codeboomer.state")
    do
      local old_timer_3_auto = st_2_auto.timers["sqlite.session"]
      if old_timer_3_auto then
        vim_1_auto.fn.timer_stop(old_timer_3_auto)
      else
      end
    end
    st_2_auto.queries["sqlite.session"] = (1 + (st_2_auto.queries["sqlite.session"] or 0))
    local function _121_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.session"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _121_)
  else
  end
  if ok_6_auto then
    return result_7_auto
  else
    db_mod_4_auto["reset-db"]()
    return error(result_7_auto, 0)
  end
end
M["session-by-id"] = function(id)
  if id then
    local t_124_
    local function _126_()
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _125_()
        return t_5_auto:get({where = {id = id}})
      end
      ok_6_auto, result_7_auto = pcall(_125_)
      local tgt_127_ = require("codeboomer.config")
      if (tgt_127_)["debug?"](tgt_127_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.session"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.session"] = (1 + (st_2_auto.queries["sqlite.session"] or 0))
        local function _129_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.session"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _129_)
      else
      end
      if ok_6_auto then
        return result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        return error(result_7_auto, 0)
      end
    end
    t_124_ = sqlite["active-rows"](_126_())
    if (nil ~= t_124_) then
      t_124_ = t_124_[1]
    else
    end
    return t_124_
  else
    return nil
  end
end
M["comment-by-gh"] = function(gh_id)
  if gh_id then
    local t_134_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _135_()
        return t_5_auto:get({where = {gh_comment_id = tostring(gh_id)}})
      end
      ok_6_auto, result_7_auto = pcall(_135_)
      local tgt_136_ = require("codeboomer.config")
      if (tgt_136_)["debug?"](tgt_136_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
        local function _138_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _138_)
      else
      end
      if ok_6_auto then
        t_134_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_134_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_134_) then
      t_134_ = t_134_[1]
    else
    end
    return t_134_
  else
    return nil
  end
end
M["thread-id-for-gh"] = function(gh_id)
  if gh_id then
    local t_143_ = M["comment-by-gh"](gh_id)
    if (nil ~= t_143_) then
      t_143_ = t_143_.thread_id
    else
    end
    return t_143_
  else
    return nil
  end
end
M["with-gh-user"] = function(login)
  local email = ((login or "unknown") .. "@users.noreply.github.com")
  local entry_3f
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _146_()
      return t_5_auto:get({where = {email = email}})
    end
    ok_6_auto, result_7_auto = pcall(_146_)
    local tgt_147_ = require("codeboomer.config")
    if (tgt_147_)["debug?"](tgt_147_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.user"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.user"] = (1 + (st_2_auto.queries["sqlite.user"] or 0))
      local function _149_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _149_)
    else
    end
    if ok_6_auto then
      entry_3f = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      entry_3f = error(result_7_auto, 0)
    end
  end
  local _153_
  do
    local t_152_ = entry_3f
    if (nil ~= t_152_) then
      t_152_ = t_152_[1]
    else
    end
    if (nil ~= t_152_) then
      t_152_ = t_152_.id
    else
    end
    _153_ = t_152_
  end
  if _153_ then
    local t_156_ = entry_3f
    if (nil ~= t_156_) then
      t_156_ = t_156_[1]
    else
    end
    if (nil ~= t_156_) then
      t_156_ = t_156_.id
    else
    end
    return t_156_
  else
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _159_()
      return t_5_auto:insert({name = (login or "unknown"), email = email})
    end
    ok_6_auto, result_7_auto = pcall(_159_)
    local tgt_160_ = require("codeboomer.config")
    if (tgt_160_)["debug?"](tgt_160_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.user"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.user"] = (1 + (st_2_auto.queries["sqlite.user"] or 0))
      local function _162_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _162_)
    else
    end
    if ok_6_auto then
      return result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      return error(result_7_auto, 0)
    end
  end
end
M["import-thread"] = function(session_id, item)
  local repo_id = with_repo()
  local login
  do
    local t_166_ = item
    if (nil ~= t_166_) then
      t_166_ = t_166_.user
    else
    end
    if (nil ~= t_166_) then
      t_166_ = t_166_.login
    else
    end
    login = t_166_
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
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _170_()
      local _171_
      if file_3f then
        _171_ = "file"
      else
        _171_ = "line"
      end
      local _173_
      if (not file_3f and not item.position) then
        _173_ = 1
      else
        _173_ = nil
      end
      return t_5_auto:insert({session_id = session_id, file_path = item.path, line_start = line, line_end = line, anchor_commit = commit_id, status = "open", type = _171_, kind = "review", gh_outdated = _173_, created_by = M["with-gh-user"](login)})
    end
    ok_6_auto, result_7_auto = pcall(_170_)
    local tgt_175_ = require("codeboomer.config")
    if (tgt_175_)["debug?"](tgt_175_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
      local function _177_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _177_)
    else
    end
    if ok_6_auto then
      thread_id = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      thread_id = error(result_7_auto, 0)
    end
  end
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _180_()
      return t_5_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](login), body = sql_literal(item.body), source = "github", commit_id = commit_id, gh_comment_id = tostring(item.id)})
    end
    ok_6_auto, result_7_auto = pcall(_180_)
    local tgt_181_ = require("codeboomer.config")
    if (tgt_181_)["debug?"](tgt_181_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
      local function _183_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _183_)
    else
    end
    if ok_6_auto then
    else
      db_mod_4_auto["reset-db"]()
      error(result_7_auto, 0)
    end
  end
  return thread_id
end
M["import-comment"] = function(thread_id, item)
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _186_()
    local function _188_()
      local t_187_ = item
      if (nil ~= t_187_) then
        t_187_ = t_187_.user
      else
      end
      if (nil ~= t_187_) then
        t_187_ = t_187_.login
      else
      end
      return t_187_
    end
    return t_5_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](_188_()), body = sql_literal(item.body), source = "github", commit_id = with_commit(with_repo(), item.commit_id), gh_comment_id = tostring(item.id)})
  end
  ok_6_auto, result_7_auto = pcall(_186_)
  local tgt_191_ = require("codeboomer.config")
  if (tgt_191_)["debug?"](tgt_191_) then
    local vim_1_auto = _G.vim
    local st_2_auto = require("codeboomer.state")
    do
      local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
      if old_timer_3_auto then
        vim_1_auto.fn.timer_stop(old_timer_3_auto)
      else
      end
    end
    st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
    local function _193_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _193_)
  else
  end
  if ok_6_auto then
    return result_7_auto
  else
    db_mod_4_auto["reset-db"]()
    return error(result_7_auto, 0)
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
  local t_198_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _199_()
      return t_5_auto:get({where = {id = (id or 0)}})
    end
    ok_6_auto, result_7_auto = pcall(_199_)
    local tgt_200_ = require("codeboomer.config")
    if (tgt_200_)["debug?"](tgt_200_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
      local function _202_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _202_)
    else
    end
    if ok_6_auto then
      t_198_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_198_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_198_) then
    t_198_ = t_198_[1]
  else
  end
  return t_198_
end
local function root_of(t)
  local _206_
  if t.parent_id then
    _206_ = thread_by_id(t.parent_id)
  else
    _206_ = nil
  end
  return (_206_ or t)
end
local function twin_of(t)
  local root = root_of(t)
  if ((root.id or 0) == (t.id or 0)) then
    local t_208_
    local function _210_()
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _209_()
        return t_5_auto:get({where = {parent_id = (t.id or 0)}})
      end
      ok_6_auto, result_7_auto = pcall(_209_)
      local tgt_211_ = require("codeboomer.config")
      if (tgt_211_)["debug?"](tgt_211_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
        local function _213_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _213_)
      else
      end
      if ok_6_auto then
        return result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        return error(result_7_auto, 0)
      end
    end
    t_208_ = sqlite["active-rows"](_210_())
    if (nil ~= t_208_) then
      t_208_ = t_208_[1]
    else
    end
    return t_208_
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
    local function _219_()
      if (twin and ((twin.id or 0) ~= (root.id or 0))) then
        return M["comments-for"](twin.id)
      else
        return {}
      end
    end
    rows = vim.list_extend(M["comments-for"]((root.id or 0)), _219_())
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
        local db_mod_4_auto = require("codeboomer.singleton")
        local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
        local ok_6_auto, result_7_auto
        local function _221_()
          return t_5_auto:insert({session_id = t.session_id, file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = t.anchor_commit, status = "open", type = (t.type or "line"), kind = "local", parent_id = t.id, created_by = with_user()})
        end
        ok_6_auto, result_7_auto = pcall(_221_)
        local tgt_222_ = require("codeboomer.config")
        if (tgt_222_)["debug?"](tgt_222_) then
          local vim_1_auto = _G.vim
          local st_2_auto = require("codeboomer.state")
          do
            local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
            if old_timer_3_auto then
              vim_1_auto.fn.timer_stop(old_timer_3_auto)
            else
            end
          end
          st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
          local function _224_()
            vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
            st_2_auto.queries["sqlite.thread"] = nil
            return nil
          end
          st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _224_)
        else
        end
        if ok_6_auto then
          id = result_7_auto
        else
          db_mod_4_auto["reset-db"]()
          id = error(result_7_auto, 0)
        end
      end
      return thread_by_id(id)
    end
  end
end
M.promote = function(thread_id, body, _3fsession_id, _3fanchor_sha)
  local t = thread_by_id(thread_id)
  local refuse
  local function _229_(msg, level)
    vim.notify(msg, level)
    return nil
  end
  refuse = _229_
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
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _230_()
        return t_5_auto:insert({session_id = (_3fsession_id or t.session_id), file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = commit_id, status = "open", type = (t.type or "line"), kind = "review", parent_id = t.id, created_by = with_user()})
      end
      ok_6_auto, result_7_auto = pcall(_230_)
      local tgt_231_ = require("codeboomer.config")
      if (tgt_231_)["debug?"](tgt_231_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
        local function _233_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _233_)
      else
      end
      if ok_6_auto then
        twin_id = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        twin_id = error(result_7_auto, 0)
      end
    end
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _236_()
        return t_5_auto:insert({thread_id = twin_id, author_id = with_user(), body = sql_literal(body), source = "user", commit_id = commit_id})
      end
      ok_6_auto, result_7_auto = pcall(_236_)
      local tgt_237_ = require("codeboomer.config")
      if (tgt_237_)["debug?"](tgt_237_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
        local function _239_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _239_)
      else
      end
      if ok_6_auto then
      else
        db_mod_4_auto["reset-db"]()
        error(result_7_auto, 0)
      end
    end
    return twin_id
  end
end
M["update-comment-body"] = function(comment_id, body)
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _243_()
    return t_5_auto:update({set = {body = sql_literal(body)}, where = {id = (comment_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_243_)
  local tgt_244_ = require("codeboomer.config")
  if (tgt_244_)["debug?"](tgt_244_) then
    local vim_1_auto = _G.vim
    local st_2_auto = require("codeboomer.state")
    do
      local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
      if old_timer_3_auto then
        vim_1_auto.fn.timer_stop(old_timer_3_auto)
      else
      end
    end
    st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
    local function _246_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _246_)
  else
  end
  if ok_6_auto then
    return result_7_auto
  else
    db_mod_4_auto["reset-db"]()
    return error(result_7_auto, 0)
  end
end
M["stamp-gh-comment"] = function(comment_id, gh_id)
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _249_()
    return t_5_auto:update({set = {gh_comment_id = tostring(gh_id)}, where = {id = (comment_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_249_)
  local tgt_250_ = require("codeboomer.config")
  if (tgt_250_)["debug?"](tgt_250_) then
    local vim_1_auto = _G.vim
    local st_2_auto = require("codeboomer.state")
    do
      local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
      if old_timer_3_auto then
        vim_1_auto.fn.timer_stop(old_timer_3_auto)
      else
      end
    end
    st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
    local function _252_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _252_)
  else
  end
  if ok_6_auto then
    return result_7_auto
  else
    db_mod_4_auto["reset-db"]()
    return error(result_7_auto, 0)
  end
end
M["agent-reply"] = function(thread_id, body)
  local rows
  local _255_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _256_()
      return t_5_auto:get({where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_256_)
    local tgt_257_ = require("codeboomer.config")
    if (tgt_257_)["debug?"](tgt_257_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
      local function _259_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _259_)
    else
    end
    if ok_6_auto then
      _255_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _255_ = error(result_7_auto, 0)
    end
  end
  rows = (_255_ or {})
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
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _263_()
        return t_5_auto:insert({thread_id = target.id, author_id = with_agent_user(), body = sql_literal(body), source = "agent", commit_id = target.anchor_commit})
      end
      ok_6_auto, result_7_auto = pcall(_263_)
      local tgt_264_ = require("codeboomer.config")
      if (tgt_264_)["debug?"](tgt_264_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
        local function _266_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _266_)
      else
      end
      if ok_6_auto then
        return result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        return error(result_7_auto, 0)
      end
    else
      return nil
    end
  end
end
M["user-reply"] = function(thread_id, body)
  local rows
  local _271_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _272_()
      return t_5_auto:get({where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_272_)
    local tgt_273_ = require("codeboomer.config")
    if (tgt_273_)["debug?"](tgt_273_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
      local function _275_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _275_)
    else
    end
    if ok_6_auto then
      _271_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _271_ = error(result_7_auto, 0)
    end
  end
  rows = (_271_ or {})
  local thread = rows[1]
  if (not thread or thread.deleted_at or (thread.status == "resolved")) then
    vim.notify(("codeboomer: no active thread #" .. tostring(thread_id)), vim.log.levels.ERROR)
    return nil
  elseif ("" == (body or "")) then
    vim.notify("codeboomer: empty reply body", vim.log.levels.ERROR)
    return nil
  else
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _278_()
      return t_5_auto:insert({thread_id = thread_id, author_id = with_user(), body = sql_literal(body), source = "user", commit_id = thread.anchor_commit})
    end
    ok_6_auto, result_7_auto = pcall(_278_)
    local tgt_279_ = require("codeboomer.config")
    if (tgt_279_)["debug?"](tgt_279_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
      local function _281_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _281_)
    else
    end
    if ok_6_auto then
      return result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      return error(result_7_auto, 0)
    end
  end
end
M["resolve-thread"] = function(thread_id)
  local t = thread_by_id(thread_id)
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _285_()
      return t_5_auto:update({set = {status = "resolved"}, where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_285_)
    local tgt_286_ = require("codeboomer.config")
    if (tgt_286_)["debug?"](tgt_286_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
      local function _288_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _288_)
    else
    end
    if ok_6_auto then
    else
      db_mod_4_auto["reset-db"]()
      error(result_7_auto, 0)
    end
  end
  local twin
  if t then
    twin = twin_of(t)
  else
    twin = nil
  end
  if twin then
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _292_()
      return t_5_auto:update({set = {status = "resolved"}, where = {id = twin.id}})
    end
    ok_6_auto, result_7_auto = pcall(_292_)
    local tgt_293_ = require("codeboomer.config")
    if (tgt_293_)["debug?"](tgt_293_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
      local function _295_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _295_)
    else
    end
    if ok_6_auto then
      return result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      return error(result_7_auto, 0)
    end
  else
    return nil
  end
end
M["commit-sha"] = function(commit_id)
  local t_299_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.commit(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _300_()
      return t_5_auto:get({where = {id = commit_id}})
    end
    ok_6_auto, result_7_auto = pcall(_300_)
    local tgt_301_ = require("codeboomer.config")
    if (tgt_301_)["debug?"](tgt_301_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.commit"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.commit"] = (1 + (st_2_auto.queries["sqlite.commit"] or 0))
      local function _303_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.commit"]) .. " " .. "sqlite.commit"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.commit"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.commit"] = vim_1_auto.fn.timer_start(1000, _303_)
    else
    end
    if ok_6_auto then
      t_299_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_299_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_299_) then
    t_299_ = t_299_[1]
  else
  end
  if (nil ~= t_299_) then
    t_299_ = t_299_.hash
  else
  end
  return t_299_
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
    local db_mod_8_auto = require("codeboomer.singleton")
    local ok_9_auto, result_10_auto
    local function _314_()
      local function _315_(d)
        for _, id in ipairs(ids) do
          d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
        end
        return nil
      end
      return db_mod_8_auto["get-db"]():with_open(_315_)
    end
    ok_9_auto, result_10_auto = pcall(_314_)
    local tgt_316_ = require("codeboomer.config")
    if (tgt_316_)["debug?"](tgt_316_) then
      local vim_11_auto = _G.vim
      vim_11_auto.notify("opening connection to sqlite", vim_11_auto.log.levels.INFO)
    else
    end
    if ok_9_auto then
      return result_10_auto
    else
      db_mod_8_auto["reset-db"]()
      return error(result_10_auto, 0)
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
    local _321_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _322_()
        return t_5_auto:get({where = {session_id = session_id}})
      end
      ok_6_auto, result_7_auto = pcall(_322_)
      local tgt_323_ = require("codeboomer.config")
      if (tgt_323_)["debug?"](tgt_323_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
        local function _325_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _325_)
      else
      end
      if ok_6_auto then
        _321_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        _321_ = error(result_7_auto, 0)
      end
    end
    rows = unresolved_rows(sqlite["active-rows"]((_321_ or {})))
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
    local _330_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _331_()
        return t_5_auto:get({where = {session_id = session_id, kind = "review"}})
      end
      ok_6_auto, result_7_auto = pcall(_331_)
      local tgt_332_ = require("codeboomer.config")
      if (tgt_332_)["debug?"](tgt_332_) then
        local vim_1_auto = _G.vim
        local st_2_auto = require("codeboomer.state")
        do
          local old_timer_3_auto = st_2_auto.timers["sqlite.thread"]
          if old_timer_3_auto then
            vim_1_auto.fn.timer_stop(old_timer_3_auto)
          else
          end
        end
        st_2_auto.queries["sqlite.thread"] = (1 + (st_2_auto.queries["sqlite.thread"] or 0))
        local function _334_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _334_)
      else
      end
      if ok_6_auto then
        _330_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        _330_ = error(result_7_auto, 0)
      end
    end
    rows = unresolved_rows(sqlite["active-rows"]((_330_ or {})))
    table.sort(rows, by_file_then_line)
    return rows
  end
end
M["comments-for"] = function(thread_id)
  local rows
  local _338_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _339_()
      return t_5_auto:get({where = {thread_id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_339_)
    local tgt_340_ = require("codeboomer.config")
    if (tgt_340_)["debug?"](tgt_340_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.comments"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.comments"] = (1 + (st_2_auto.queries["sqlite.comments"] or 0))
      local function _342_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _342_)
    else
    end
    if ok_6_auto then
      _338_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _338_ = error(result_7_auto, 0)
    end
  end
  rows = sqlite["active-rows"]((_338_ or {}))
  table.sort(rows, by_created)
  return rows
end
M["comment-author"] = function(c)
  local t_345_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _346_()
      return t_5_auto:get({where = {id = (c.author_id or 0)}})
    end
    ok_6_auto, result_7_auto = pcall(_346_)
    local tgt_347_ = require("codeboomer.config")
    if (tgt_347_)["debug?"](tgt_347_) then
      local vim_1_auto = _G.vim
      local st_2_auto = require("codeboomer.state")
      do
        local old_timer_3_auto = st_2_auto.timers["sqlite.user"]
        if old_timer_3_auto then
          vim_1_auto.fn.timer_stop(old_timer_3_auto)
        else
        end
      end
      st_2_auto.queries["sqlite.user"] = (1 + (st_2_auto.queries["sqlite.user"] or 0))
      local function _349_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _349_)
    else
    end
    if ok_6_auto then
      t_345_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_345_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_345_) then
    t_345_ = t_345_[1]
  else
  end
  return t_345_
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
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _355_()
    return t_5_auto:update({set = {deleted_at = os.time()}, where = {id = (session_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_355_)
  local tgt_356_ = require("codeboomer.config")
  if (tgt_356_)["debug?"](tgt_356_) then
    local vim_1_auto = _G.vim
    local st_2_auto = require("codeboomer.state")
    do
      local old_timer_3_auto = st_2_auto.timers["sqlite.session"]
      if old_timer_3_auto then
        vim_1_auto.fn.timer_stop(old_timer_3_auto)
      else
      end
    end
    st_2_auto.queries["sqlite.session"] = (1 + (st_2_auto.queries["sqlite.session"] or 0))
    local function _358_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.session"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _358_)
  else
  end
  if ok_6_auto then
    return result_7_auto
  else
    db_mod_4_auto["reset-db"]()
    return error(result_7_auto, 0)
  end
end
M["create-session"] = function()
  local repo_id = with_repo()
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _361_()
    return t_5_auto:insert({branch = git["branch-name"](), head_commit = with_commit(repo_id), repo_id = repo_id})
  end
  ok_6_auto, result_7_auto = pcall(_361_)
  local tgt_362_ = require("codeboomer.config")
  if (tgt_362_)["debug?"](tgt_362_) then
    local vim_1_auto = _G.vim
    local st_2_auto = require("codeboomer.state")
    do
      local old_timer_3_auto = st_2_auto.timers["sqlite.session"]
      if old_timer_3_auto then
        vim_1_auto.fn.timer_stop(old_timer_3_auto)
      else
      end
    end
    st_2_auto.queries["sqlite.session"] = (1 + (st_2_auto.queries["sqlite.session"] or 0))
    local function _364_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.session"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _364_)
  else
  end
  if ok_6_auto then
    return result_7_auto
  else
    db_mod_4_auto["reset-db"]()
    return error(result_7_auto, 0)
  end
end
return M
