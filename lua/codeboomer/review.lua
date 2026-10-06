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
local function with_user(_3fpath)
  local email = git["user-email"](_3fpath)
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
      return t_5_auto:insert({name = git["user-name"](_3fpath), email = email})
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
local function session_repo(session_id)
  local session
  do
    local t_71_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _72_()
        return t_5_auto:get({where = {id = (session_id or 0)}})
      end
      ok_6_auto, result_7_auto = pcall(_72_)
      local tgt_73_ = require("codeboomer.config")
      if (tgt_73_)["debug?"](tgt_73_) then
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
        local function _75_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.session"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _75_)
      else
      end
      if ok_6_auto then
        t_71_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_71_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_71_) then
      t_71_ = t_71_[1]
    else
    end
    session = t_71_
  end
  if session then
    local t_79_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.repo(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _80_()
        return t_5_auto:get({where = {id = session.repo_id}})
      end
      ok_6_auto, result_7_auto = pcall(_80_)
      local tgt_81_ = require("codeboomer.config")
      if (tgt_81_)["debug?"](tgt_81_) then
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
        local function _83_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.repo"]) .. " " .. "sqlite.repo"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.repo"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.repo"] = vim_1_auto.fn.timer_start(1000, _83_)
      else
      end
      if ok_6_auto then
        t_79_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_79_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_79_) then
      t_79_ = t_79_[1]
    else
    end
    return t_79_
  else
    return nil
  end
end
local function new_thread(session_id, author_id, source, anchor, body)
  local commit_id = with_commit(with_repo())
  local thread_id
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _88_()
      return t_5_auto:insert(vim.tbl_extend("force", anchor, {session_id = session_id, anchor_commit = commit_id, status = "open", kind = "local", created_by = author_id}))
    end
    ok_6_auto, result_7_auto = pcall(_88_)
    local tgt_89_ = require("codeboomer.config")
    if (tgt_89_)["debug?"](tgt_89_) then
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
      local function _91_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _91_)
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
    local function _94_()
      return t_5_auto:insert({thread_id = thread_id, author_id = author_id, body = sql_literal(body), source = source, commit_id = commit_id})
    end
    ok_6_auto, result_7_auto = pcall(_94_)
    local tgt_95_ = require("codeboomer.config")
    if (tgt_95_)["debug?"](tgt_95_) then
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
      local function _97_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _97_)
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
local function line_anchor(file_path, line_start, line_end, code)
  return {file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = sql_literal(code), type = "line"}
end
local function file_anchor(file_path)
  return {file_path = file_path, type = "file"}
end
M["user-comment"] = function(session_id, file_path, line_start, line_end, code, body)
  return new_thread(session_id, with_user(), "user", line_anchor(file_path, line_start, line_end, code), body)
end
M["file-comment"] = function(session_id, file_path, body)
  return new_thread(session_id, with_user(), "user", file_anchor(file_path), body)
end
M["agent-comment"] = function(session_id, file_path, line_start, line_end, code, body)
  return new_thread(session_id, with_agent_user(), "agent", line_anchor(file_path, line_start, line_end, code), body)
end
M["agent-file-comment"] = function(session_id, file_path, body)
  return new_thread(session_id, with_agent_user(), "agent", file_anchor(file_path), body)
end
local function repo_id_of(root)
  local t_100_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.repo(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _101_()
      return t_5_auto:get({where = {path = root}})
    end
    ok_6_auto, result_7_auto = pcall(_101_)
    local tgt_102_ = require("codeboomer.config")
    if (tgt_102_)["debug?"](tgt_102_) then
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
      local function _104_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.repo"]) .. " " .. "sqlite.repo"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.repo"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.repo"] = vim_1_auto.fn.timer_start(1000, _104_)
    else
    end
    if ok_6_auto then
      t_100_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_100_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_100_) then
    t_100_ = t_100_[1]
  else
  end
  if (nil ~= t_100_) then
    t_100_ = t_100_.id
  else
  end
  return t_100_
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
      local t_110_
      do
        local db_mod_4_auto = require("codeboomer.singleton")
        local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
        local ok_6_auto, result_7_auto
        local function _111_()
          return t_5_auto:get({where = {repo_id = repo_id, branch = branch}})
        end
        ok_6_auto, result_7_auto = pcall(_111_)
        local tgt_112_ = require("codeboomer.config")
        if (tgt_112_)["debug?"](tgt_112_) then
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
          local function _114_()
            vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
            st_2_auto.queries["sqlite.session"] = nil
            return nil
          end
          st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _114_)
        else
        end
        if ok_6_auto then
          t_110_ = result_7_auto
        else
          db_mod_4_auto["reset-db"]()
          t_110_ = error(result_7_auto, 0)
        end
      end
      if (nil ~= t_110_) then
        t_110_ = t_110_[1]
      else
      end
      return t_110_
    else
      return nil
    end
  else
    return nil
  end
end
local function create_session()
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _120_()
    return t_5_auto:insert({branch = git["branch-name"](), repo_id = with_repo()})
  end
  ok_6_auto, result_7_auto = pcall(_120_)
  local tgt_121_ = require("codeboomer.config")
  if (tgt_121_)["debug?"](tgt_121_) then
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
    local function _123_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.session"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _123_)
  else
  end
  if ok_6_auto then
    return result_7_auto
  else
    db_mod_4_auto["reset-db"]()
    return error(result_7_auto, 0)
  end
end
M["ensure-session"] = function()
  local _127_
  do
    local t_126_ = M["session-for"]()
    if (nil ~= t_126_) then
      t_126_ = t_126_.id
    else
    end
    _127_ = t_126_
  end
  local or_129_ = _127_
  if not or_129_ then
    if (git["repo-root"]() and git["branch-name"]()) then
      or_129_ = create_session()
    else
      or_129_ = nil
    end
  end
  return or_129_
end
M["set-session-pr"] = function(session_id, pr_number)
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _131_()
    return t_5_auto:update({set = {pr_number = pr_number}, where = {id = (session_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_131_)
  local tgt_132_ = require("codeboomer.config")
  if (tgt_132_)["debug?"](tgt_132_) then
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
    local function _134_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.session"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _134_)
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
    local t_137_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _138_()
        return t_5_auto:get({where = {id = id}})
      end
      ok_6_auto, result_7_auto = pcall(_138_)
      local tgt_139_ = require("codeboomer.config")
      if (tgt_139_)["debug?"](tgt_139_) then
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
        local function _141_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.session"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _141_)
      else
      end
      if ok_6_auto then
        t_137_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_137_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_137_) then
      t_137_ = t_137_[1]
    else
    end
    return t_137_
  else
    return nil
  end
end
M["comment-by-gh"] = function(gh_id)
  if gh_id then
    local t_146_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _147_()
        return t_5_auto:get({where = {gh_comment_id = tostring(gh_id)}})
      end
      ok_6_auto, result_7_auto = pcall(_147_)
      local tgt_148_ = require("codeboomer.config")
      if (tgt_148_)["debug?"](tgt_148_) then
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
        local function _150_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _150_)
      else
      end
      if ok_6_auto then
        t_146_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_146_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_146_) then
      t_146_ = t_146_[1]
    else
    end
    return t_146_
  else
    return nil
  end
end
M["thread-id-for-gh"] = function(gh_id)
  if gh_id then
    local t_155_ = M["comment-by-gh"](gh_id)
    if (nil ~= t_155_) then
      t_155_ = t_155_.thread_id
    else
    end
    return t_155_
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
    local function _158_()
      return t_5_auto:get({where = {email = email}})
    end
    ok_6_auto, result_7_auto = pcall(_158_)
    local tgt_159_ = require("codeboomer.config")
    if (tgt_159_)["debug?"](tgt_159_) then
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
      local function _161_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _161_)
    else
    end
    if ok_6_auto then
      entry_3f = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      entry_3f = error(result_7_auto, 0)
    end
  end
  local _165_
  do
    local t_164_ = entry_3f
    if (nil ~= t_164_) then
      t_164_ = t_164_[1]
    else
    end
    if (nil ~= t_164_) then
      t_164_ = t_164_.id
    else
    end
    _165_ = t_164_
  end
  if _165_ then
    local t_168_ = entry_3f
    if (nil ~= t_168_) then
      t_168_ = t_168_[1]
    else
    end
    if (nil ~= t_168_) then
      t_168_ = t_168_.id
    else
    end
    return t_168_
  else
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _171_()
      return t_5_auto:insert({name = (login or "unknown"), email = email})
    end
    ok_6_auto, result_7_auto = pcall(_171_)
    local tgt_172_ = require("codeboomer.config")
    if (tgt_172_)["debug?"](tgt_172_) then
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
      local function _174_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _174_)
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
    local t_178_ = item
    if (nil ~= t_178_) then
      t_178_ = t_178_.user
    else
    end
    if (nil ~= t_178_) then
      t_178_ = t_178_.login
    else
    end
    login = t_178_
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
    local function _182_()
      local _183_
      if file_3f then
        _183_ = "file"
      else
        _183_ = "line"
      end
      local _185_
      if (not file_3f and not item.position) then
        _185_ = 1
      else
        _185_ = nil
      end
      return t_5_auto:insert({session_id = session_id, file_path = item.path, line_start = line, line_end = line, anchor_commit = commit_id, status = "open", type = _183_, kind = "review", gh_outdated = _185_, created_by = M["with-gh-user"](login)})
    end
    ok_6_auto, result_7_auto = pcall(_182_)
    local tgt_187_ = require("codeboomer.config")
    if (tgt_187_)["debug?"](tgt_187_) then
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
      local function _189_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _189_)
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
    local function _192_()
      return t_5_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](login), body = sql_literal(item.body), source = "github", commit_id = commit_id, gh_comment_id = tostring(item.id)})
    end
    ok_6_auto, result_7_auto = pcall(_192_)
    local tgt_193_ = require("codeboomer.config")
    if (tgt_193_)["debug?"](tgt_193_) then
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
      local function _195_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _195_)
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
  local function _198_()
    local function _200_()
      local t_199_ = item
      if (nil ~= t_199_) then
        t_199_ = t_199_.user
      else
      end
      if (nil ~= t_199_) then
        t_199_ = t_199_.login
      else
      end
      return t_199_
    end
    return t_5_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](_200_()), body = sql_literal(item.body), source = "github", commit_id = with_commit(with_repo(), item.commit_id), gh_comment_id = tostring(item.id)})
  end
  ok_6_auto, result_7_auto = pcall(_198_)
  local tgt_203_ = require("codeboomer.config")
  if (tgt_203_)["debug?"](tgt_203_) then
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
    local function _205_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _205_)
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
  local t_210_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _211_()
      return t_5_auto:get({where = {id = (id or 0)}})
    end
    ok_6_auto, result_7_auto = pcall(_211_)
    local tgt_212_ = require("codeboomer.config")
    if (tgt_212_)["debug?"](tgt_212_) then
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
      local function _214_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _214_)
    else
    end
    if ok_6_auto then
      t_210_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_210_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_210_) then
    t_210_ = t_210_[1]
  else
  end
  return t_210_
end
local function root_of(t)
  local _218_
  if t.parent_id then
    _218_ = thread_by_id(t.parent_id)
  else
    _218_ = nil
  end
  return (_218_ or t)
end
local function twin_of(t)
  local root = root_of(t)
  if ((root.id or 0) == (t.id or 0)) then
    local t_220_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _221_()
        return t_5_auto:get({where = {parent_id = (t.id or 0)}})
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
        t_220_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_220_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_220_) then
      t_220_ = t_220_[1]
    else
    end
    return t_220_
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
    local function _230_()
      if (twin and ((twin.id or 0) ~= (root.id or 0))) then
        return M["comments-for"](twin.id)
      else
        return {}
      end
    end
    rows = vim.list_extend(M["comments-for"]((root.id or 0)), _230_())
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
        local function _232_()
          local function _234_()
            local t_233_ = session_repo(t.session_id)
            if (nil ~= t_233_) then
              t_233_ = t_233_.path
            else
            end
            return t_233_
          end
          return t_5_auto:insert({session_id = t.session_id, file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = t.anchor_commit, status = "open", type = (t.type or "line"), kind = "local", parent_id = t.id, created_by = with_user(_234_())})
        end
        ok_6_auto, result_7_auto = pcall(_232_)
        local tgt_236_ = require("codeboomer.config")
        if (tgt_236_)["debug?"](tgt_236_) then
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
          local function _238_()
            vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
            st_2_auto.queries["sqlite.thread"] = nil
            return nil
          end
          st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _238_)
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
local function significant(s)
  local trimmed
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, l in ipairs(vim.split((s or ""), "\n")) do
      local val_28_ = l:gsub("[ \t]+$", "")
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    trimmed = tbl_26_
  end
  local from = 1
  local to = #trimmed
  while ((from <= to) and ("" == trimmed[from])) do
    from = (from + 1)
  end
  while ((from < to) and ("" == trimmed[to])) do
    to = (to - 1)
  end
  local out = {}
  for i = from, to do
    table.insert(out, trimmed[i])
  end
  return table.concat(out, "\n")
end
local function clip(s)
  local s0 = (s or "<end>")
  if (#s0 > 48) then
    return (s0:sub(1, 45) .. "...")
  else
    return s0
  end
end
local function mismatch_detail(t)
  if ("file" == (t.type or "line")) then
    return nil
  elseif not t.anchor_commit then
    return nil
  else
    local sha = M["commit-sha"](t.anchor_commit)
    if not sha then
      return nil
    else
      local out = git.run(git["repo-root"](), "show", (sha .. ":" .. (t.file_path or "")))
      if not out then
        return string.format("%s doesn't exist at the anchor", (t.file_path or "?"))
      else
        local file_lines = vim.split(out, "\n")
        local line_end = (t.line_end or (t.line_start or 1))
        if (#file_lines < line_end) then
          return string.format("the anchor has only %d lines \226\128\148 the range runs past its end", #file_lines)
        else
          local expected = {}
          for i = (t.line_start or 1), line_end do
            table.insert(expected, file_lines[i])
          end
          local a = significant(table.concat(expected, "\n"))
          local b = significant((t.code_snapshot or ""))
          if (a == b) then
            return nil
          else
            local al = vim.split(a, "\n")
            local bl = vim.split(b, "\n")
            local at = nil
            local limit = math.max(#al, #bl)
            for i = 1, limit do
              if at then break end
              if (al[i] ~= bl[i]) then
                at = i
              else
              end
            end
            return string.format("first difference: anchor has %s, snapshot has %s", clip(al[at]), clip(bl[at]))
          end
        end
      end
    end
  end
end
local function snapshot_matches_3f(t)
  return not mismatch_detail(t)
end
M.promote = function(thread_id, body, _3fsession_id, _3fanchor_sha)
  local t = thread_by_id(thread_id)
  local refuse
  local function _251_(msg, level)
    vim.notify(msg, level)
    return nil
  end
  refuse = _251_
  if not t then
    return refuse(("codeboomer: no thread #" .. tostring((thread_id or 0))), vim.log.levels.ERROR)
  elseif ("review" == (t.kind or "local")) then
    return refuse("codeboomer: this thread is already a review thread", vim.log.levels.WARN)
  elseif twin_of(t) then
    return refuse(string.format("codeboomer: thread #%d already promoted", (t.id or 0)), vim.log.levels.WARN)
  elseif not snapshot_matches_3f(t) then
    return refuse(string.format("codeboomer: thread #%d can't promote \226\128\148 snapshot doesn't match anchor %s in %s: %s; re-annotate at the current state", (t.id or 0), (M["commit-sha"]((t.anchor_commit or 0)) or "?"), (t.file_path or "?"), mismatch_detail(t)), vim.log.levels.ERROR)
  elseif ("" == vim.trim((body or ""))) then
    return refuse("codeboomer: empty promotion ignored", vim.log.levels.WARN)
  else
    local repo = session_repo(t.session_id)
    local me
    local function _253_()
      local t_252_ = repo
      if (nil ~= t_252_) then
        t_252_ = t_252_.path
      else
      end
      return t_252_
    end
    me = with_user(_253_())
    local commit_id
    local _256_
    do
      local t_255_ = repo
      if (nil ~= t_255_) then
        t_255_ = t_255_.id
      else
      end
      _256_ = t_255_
    end
    commit_id = with_commit(_256_, (_3fanchor_sha or M["commit-sha"](t.anchor_commit)))
    local twin_id
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _258_()
        return t_5_auto:insert({session_id = (_3fsession_id or t.session_id), file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = commit_id, status = "open", type = (t.type or "line"), kind = "review", parent_id = t.id, created_by = me})
      end
      ok_6_auto, result_7_auto = pcall(_258_)
      local tgt_259_ = require("codeboomer.config")
      if (tgt_259_)["debug?"](tgt_259_) then
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
        local function _261_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _261_)
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
      local function _264_()
        return t_5_auto:insert({thread_id = twin_id, author_id = me, body = sql_literal(body), source = "user", commit_id = commit_id})
      end
      ok_6_auto, result_7_auto = pcall(_264_)
      local tgt_265_ = require("codeboomer.config")
      if (tgt_265_)["debug?"](tgt_265_) then
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
        local function _267_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _267_)
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
  local function _271_()
    return t_5_auto:update({set = {body = sql_literal(body)}, where = {id = (comment_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_271_)
  local tgt_272_ = require("codeboomer.config")
  if (tgt_272_)["debug?"](tgt_272_) then
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
    local function _274_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _274_)
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
  local function _277_()
    return t_5_auto:update({set = {gh_comment_id = tostring(gh_id)}, where = {id = (comment_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_277_)
  local tgt_278_ = require("codeboomer.config")
  if (tgt_278_)["debug?"](tgt_278_) then
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
    local function _280_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _280_)
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
  local _283_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _284_()
      return t_5_auto:get({where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_284_)
    local tgt_285_ = require("codeboomer.config")
    if (tgt_285_)["debug?"](tgt_285_) then
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
      local function _287_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _287_)
    else
    end
    if ok_6_auto then
      _283_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _283_ = error(result_7_auto, 0)
    end
  end
  rows = (_283_ or {})
  local thread = rows[1]
  if (not thread or (thread.status == "resolved")) then
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
      local function _291_()
        return t_5_auto:insert({thread_id = target.id, author_id = with_agent_user(), body = sql_literal(body), source = "agent", commit_id = target.anchor_commit})
      end
      ok_6_auto, result_7_auto = pcall(_291_)
      local tgt_292_ = require("codeboomer.config")
      if (tgt_292_)["debug?"](tgt_292_) then
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
        local function _294_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _294_)
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
  local _299_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _300_()
      return t_5_auto:get({where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_300_)
    local tgt_301_ = require("codeboomer.config")
    if (tgt_301_)["debug?"](tgt_301_) then
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
      local function _303_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _303_)
    else
    end
    if ok_6_auto then
      _299_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _299_ = error(result_7_auto, 0)
    end
  end
  rows = (_299_ or {})
  local thread = rows[1]
  if (not thread or (thread.status == "resolved")) then
    vim.notify(("codeboomer: no active thread #" .. tostring(thread_id)), vim.log.levels.ERROR)
    return nil
  elseif ("" == (body or "")) then
    vim.notify("codeboomer: empty reply body", vim.log.levels.ERROR)
    return nil
  else
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _306_()
      local function _308_()
        local t_307_ = session_repo(thread.session_id)
        if (nil ~= t_307_) then
          t_307_ = t_307_.path
        else
        end
        return t_307_
      end
      return t_5_auto:insert({thread_id = thread_id, author_id = with_user(_308_()), body = sql_literal(body), source = "user", commit_id = thread.anchor_commit})
    end
    ok_6_auto, result_7_auto = pcall(_306_)
    local tgt_310_ = require("codeboomer.config")
    if (tgt_310_)["debug?"](tgt_310_) then
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
      local function _312_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _312_)
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
    local function _316_()
      return t_5_auto:update({set = {status = "resolved"}, where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_316_)
    local tgt_317_ = require("codeboomer.config")
    if (tgt_317_)["debug?"](tgt_317_) then
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
      local function _319_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _319_)
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
    local function _323_()
      return t_5_auto:update({set = {status = "resolved"}, where = {id = twin.id}})
    end
    ok_6_auto, result_7_auto = pcall(_323_)
    local tgt_324_ = require("codeboomer.config")
    if (tgt_324_)["debug?"](tgt_324_) then
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
      local function _326_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _326_)
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
  local t_330_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.commit(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _331_()
      return t_5_auto:get({where = {id = commit_id}})
    end
    ok_6_auto, result_7_auto = pcall(_331_)
    local tgt_332_ = require("codeboomer.config")
    if (tgt_332_)["debug?"](tgt_332_) then
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
      local function _334_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.commit"]) .. " " .. "sqlite.commit"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.commit"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.commit"] = vim_1_auto.fn.timer_start(1000, _334_)
    else
    end
    if ok_6_auto then
      t_330_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_330_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_330_) then
    t_330_ = t_330_[1]
  else
  end
  if (nil ~= t_330_) then
    t_330_ = t_330_.hash
  else
  end
  return t_330_
end
local function mine_unflagged_3f(c, me, flag)
  return (((c.author_id or 0) == me) and ((c.source or "user") == "user") and (0 == (c[flag] or 0)) and ("" ~= (c.body or "")))
end
M["unposted-user-comments"] = function(thread_id)
  local me
  local function _340_()
    local t_339_
    local function _342_()
      local t_341_ = thread_by_id(thread_id)
      if (nil ~= t_341_) then
        t_341_ = t_341_.session_id
      else
      end
      return t_341_
    end
    t_339_ = session_repo(_342_())
    if (nil ~= t_339_) then
      t_339_ = t_339_.path
    else
    end
    return t_339_
  end
  me = with_user(_340_())
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
    local me
    local function _348_()
      local t_347_ = session_repo(session_id)
      if (nil ~= t_347_) then
        t_347_ = t_347_.path
      else
      end
      return t_347_
    end
    me = with_user(_348_())
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
    local me
    local function _353_()
      local t_352_ = session_repo(session_id)
      if (nil ~= t_352_) then
        t_352_ = t_352_.path
      else
      end
      return t_352_
    end
    me = with_user(_353_())
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
    local function _357_()
      local function _358_(d)
        for _, id in ipairs(ids) do
          d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
        end
        return nil
      end
      return db_mod_8_auto["get-db"]():with_open(_358_)
    end
    ok_9_auto, result_10_auto = pcall(_357_)
    local tgt_359_ = require("codeboomer.config")
    if (tgt_359_)["debug?"](tgt_359_) then
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
M["delete-comment"] = function(comment_id)
  local c
  do
    local t_363_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _364_()
        return t_5_auto:get({where = {id = (comment_id or 0)}})
      end
      ok_6_auto, result_7_auto = pcall(_364_)
      local tgt_365_ = require("codeboomer.config")
      if (tgt_365_)["debug?"](tgt_365_) then
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
        local function _367_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _367_)
      else
      end
      if ok_6_auto then
        t_363_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_363_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_363_) then
      t_363_ = t_363_[1]
    else
    end
    c = t_363_
  end
  if (c and ("user" == (c.source or "user")) and (0 == (c.sent or 0)) and (0 == (c.posted or 0)) and not c.gh_comment_id) then
    do
      local db_mod_8_auto = require("codeboomer.singleton")
      local ok_9_auto, result_10_auto
      local function _371_()
        local function _372_(d)
          return d:execute(string.format("delete from comment where id = %d", (c.id or 0)))
        end
        return db_mod_8_auto["get-db"]():with_open(_372_)
      end
      ok_9_auto, result_10_auto = pcall(_371_)
      local tgt_373_ = require("codeboomer.config")
      if (tgt_373_)["debug?"](tgt_373_) then
        local vim_11_auto = _G.vim
        vim_11_auto.notify("opening connection to sqlite", vim_11_auto.log.levels.INFO)
      else
      end
      if ok_9_auto then
      else
        db_mod_8_auto["reset-db"]()
        error(result_10_auto, 0)
      end
    end
    return true
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
    local _378_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _379_()
        return t_5_auto:get({where = {session_id = session_id}})
      end
      ok_6_auto, result_7_auto = pcall(_379_)
      local tgt_380_ = require("codeboomer.config")
      if (tgt_380_)["debug?"](tgt_380_) then
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
        local function _382_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _382_)
      else
      end
      if ok_6_auto then
        _378_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        _378_ = error(result_7_auto, 0)
      end
    end
    rows = unresolved_rows((_378_ or {}))
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
    local _387_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _388_()
        return t_5_auto:get({where = {session_id = session_id, kind = "review"}})
      end
      ok_6_auto, result_7_auto = pcall(_388_)
      local tgt_389_ = require("codeboomer.config")
      if (tgt_389_)["debug?"](tgt_389_) then
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
        local function _391_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _391_)
      else
      end
      if ok_6_auto then
        _387_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        _387_ = error(result_7_auto, 0)
      end
    end
    rows = unresolved_rows((_387_ or {}))
    table.sort(rows, by_file_then_line)
    return rows
  end
end
M["comments-for"] = function(thread_id)
  local rows
  local _395_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _396_()
      return t_5_auto:get({where = {thread_id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_396_)
    local tgt_397_ = require("codeboomer.config")
    if (tgt_397_)["debug?"](tgt_397_) then
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
      local function _399_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _399_)
    else
    end
    if ok_6_auto then
      _395_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _395_ = error(result_7_auto, 0)
    end
  end
  rows = (_395_ or {})
  table.sort(rows, by_created)
  return rows
end
M["comment-author"] = function(c)
  local t_402_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _403_()
      return t_5_auto:get({where = {id = (c.author_id or 0)}})
    end
    ok_6_auto, result_7_auto = pcall(_403_)
    local tgt_404_ = require("codeboomer.config")
    if (tgt_404_)["debug?"](tgt_404_) then
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
      local function _406_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _406_)
    else
    end
    if ok_6_auto then
      t_402_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_402_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_402_) then
    t_402_ = t_402_[1]
  else
  end
  return t_402_
end
M["match-posted-comment"] = function(session_id, item)
  local line = (item.original_line or item.line)
  local file_3f = ("file" == item.subject_type)
  local want_path = (item.path or "")
  local want_body = (item.body or "")
  local function anchored_3f(r)
    if file_3f then
      return ("file" == r.type)
    else
      return (line and (line >= (r.line_start or 0)) and (line <= (r.line_end or 0)))
    end
  end
  local found = nil
  for _, r in ipairs(M["review-rows-for-session"](session_id)) do
    if found then break end
    if ((want_path == (r.file_path or "")) and anchored_3f(r)) then
      for _0, c in ipairs(M["comments-for"]((r.id or 0))) do
        if found then break end
        if ((1 == (c.posted or 0)) and (nil == c.gh_comment_id) and (want_body == (c.body or ""))) then
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
  local threads = string.format("select id from comment_thread where session_id = %d", (session_id or 0))
  local db_mod_8_auto = require("codeboomer.singleton")
  local ok_9_auto, result_10_auto
  local function _413_()
    local function _414_(d)
      return d:execute(string.format("begin;\n                                               delete from comment where thread_id in (%s);\n                                               update comment_thread set parent_id = null\n                                                 where parent_id in (%s) and session_id != %d;\n                                               delete from comment_thread where session_id = %d;\n                                               delete from session where id = %d;\n                                               commit;", threads, threads, (session_id or 0), (session_id or 0), (session_id or 0)))
    end
    return db_mod_8_auto["get-db"]():with_open(_414_)
  end
  ok_9_auto, result_10_auto = pcall(_413_)
  local tgt_415_ = require("codeboomer.config")
  if (tgt_415_)["debug?"](tgt_415_) then
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
end
return M
