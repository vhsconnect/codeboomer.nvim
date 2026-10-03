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
M["user-comment"] = function(session_id, file_path, line_start, line_end, code, body)
  local user_id = with_user()
  local repo_id = with_repo()
  local commit_id = with_commit(repo_id)
  local thread_id
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _88_()
      return t_5_auto:insert({session_id = session_id, file_path = file_path, line_start = line_start, line_end = line_end, code_snapshot = sql_literal(code), anchor_commit = commit_id, status = "open", type = "line", kind = "local", created_by = user_id})
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
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _94_()
    return t_5_auto:insert({thread_id = thread_id, author_id = user_id, body = sql_literal(body), source = "user", commit_id = commit_id})
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
    local function _100_()
      return t_5_auto:insert({session_id = session_id, file_path = file_path, anchor_commit = commit_id, status = "open", type = "file", kind = "local", created_by = user_id})
    end
    ok_6_auto, result_7_auto = pcall(_100_)
    local tgt_101_ = require("codeboomer.config")
    if (tgt_101_)["debug?"](tgt_101_) then
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
      local function _103_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _103_)
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
  local function _106_()
    return t_5_auto:insert({thread_id = thread_id, author_id = user_id, body = sql_literal(body), source = "user", commit_id = commit_id})
  end
  ok_6_auto, result_7_auto = pcall(_106_)
  local tgt_107_ = require("codeboomer.config")
  if (tgt_107_)["debug?"](tgt_107_) then
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
    local function _109_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _109_)
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
  local t_112_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.repo(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _113_()
      return t_5_auto:get({where = {path = root}})
    end
    ok_6_auto, result_7_auto = pcall(_113_)
    local tgt_114_ = require("codeboomer.config")
    if (tgt_114_)["debug?"](tgt_114_) then
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
      local function _116_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.repo"]) .. " " .. "sqlite.repo"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.repo"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.repo"] = vim_1_auto.fn.timer_start(1000, _116_)
    else
    end
    if ok_6_auto then
      t_112_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_112_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_112_) then
    t_112_ = t_112_[1]
  else
  end
  if (nil ~= t_112_) then
    t_112_ = t_112_.id
  else
  end
  return t_112_
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
      local t_122_
      local function _124_()
        local db_mod_4_auto = require("codeboomer.singleton")
        local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
        local ok_6_auto, result_7_auto
        local function _123_()
          return t_5_auto:get({where = {repo_id = repo_id, branch = branch}})
        end
        ok_6_auto, result_7_auto = pcall(_123_)
        local tgt_125_ = require("codeboomer.config")
        if (tgt_125_)["debug?"](tgt_125_) then
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
          local function _127_()
            vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
            st_2_auto.queries["sqlite.session"] = nil
            return nil
          end
          st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _127_)
        else
        end
        if ok_6_auto then
          return result_7_auto
        else
          db_mod_4_auto["reset-db"]()
          return error(result_7_auto, 0)
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
  else
    return nil
  end
end
local function create_session()
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _133_()
    return t_5_auto:insert({branch = git["branch-name"](), repo_id = with_repo()})
  end
  ok_6_auto, result_7_auto = pcall(_133_)
  local tgt_134_ = require("codeboomer.config")
  if (tgt_134_)["debug?"](tgt_134_) then
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
    local function _136_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.session"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _136_)
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
  local _140_
  do
    local t_139_ = M["session-for"]()
    if (nil ~= t_139_) then
      t_139_ = t_139_.id
    else
    end
    _140_ = t_139_
  end
  local or_142_ = _140_
  if not or_142_ then
    if (git["repo-root"]() and git["branch-name"]()) then
      or_142_ = create_session()
    else
      or_142_ = nil
    end
  end
  return or_142_
end
M["set-session-pr"] = function(session_id, pr_number)
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _144_()
    return t_5_auto:update({set = {pr_number = pr_number}, where = {id = (session_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_144_)
  local tgt_145_ = require("codeboomer.config")
  if (tgt_145_)["debug?"](tgt_145_) then
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
    local function _147_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.session"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _147_)
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
    local t_150_
    local function _152_()
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _151_()
        return t_5_auto:get({where = {id = id}})
      end
      ok_6_auto, result_7_auto = pcall(_151_)
      local tgt_153_ = require("codeboomer.config")
      if (tgt_153_)["debug?"](tgt_153_) then
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
        local function _155_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.session"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _155_)
      else
      end
      if ok_6_auto then
        return result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        return error(result_7_auto, 0)
      end
    end
    t_150_ = sqlite["active-rows"](_152_())
    if (nil ~= t_150_) then
      t_150_ = t_150_[1]
    else
    end
    return t_150_
  else
    return nil
  end
end
M["comment-by-gh"] = function(gh_id)
  if gh_id then
    local t_160_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _161_()
        return t_5_auto:get({where = {gh_comment_id = tostring(gh_id)}})
      end
      ok_6_auto, result_7_auto = pcall(_161_)
      local tgt_162_ = require("codeboomer.config")
      if (tgt_162_)["debug?"](tgt_162_) then
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
        local function _164_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _164_)
      else
      end
      if ok_6_auto then
        t_160_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_160_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_160_) then
      t_160_ = t_160_[1]
    else
    end
    return t_160_
  else
    return nil
  end
end
M["thread-id-for-gh"] = function(gh_id)
  if gh_id then
    local t_169_ = M["comment-by-gh"](gh_id)
    if (nil ~= t_169_) then
      t_169_ = t_169_.thread_id
    else
    end
    return t_169_
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
    local function _172_()
      return t_5_auto:get({where = {email = email}})
    end
    ok_6_auto, result_7_auto = pcall(_172_)
    local tgt_173_ = require("codeboomer.config")
    if (tgt_173_)["debug?"](tgt_173_) then
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
      local function _175_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _175_)
    else
    end
    if ok_6_auto then
      entry_3f = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      entry_3f = error(result_7_auto, 0)
    end
  end
  local _179_
  do
    local t_178_ = entry_3f
    if (nil ~= t_178_) then
      t_178_ = t_178_[1]
    else
    end
    if (nil ~= t_178_) then
      t_178_ = t_178_.id
    else
    end
    _179_ = t_178_
  end
  if _179_ then
    local t_182_ = entry_3f
    if (nil ~= t_182_) then
      t_182_ = t_182_[1]
    else
    end
    if (nil ~= t_182_) then
      t_182_ = t_182_.id
    else
    end
    return t_182_
  else
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _185_()
      return t_5_auto:insert({name = (login or "unknown"), email = email})
    end
    ok_6_auto, result_7_auto = pcall(_185_)
    local tgt_186_ = require("codeboomer.config")
    if (tgt_186_)["debug?"](tgt_186_) then
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
      local function _188_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _188_)
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
    local t_192_ = item
    if (nil ~= t_192_) then
      t_192_ = t_192_.user
    else
    end
    if (nil ~= t_192_) then
      t_192_ = t_192_.login
    else
    end
    login = t_192_
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
    local function _196_()
      local _197_
      if file_3f then
        _197_ = "file"
      else
        _197_ = "line"
      end
      local _199_
      if (not file_3f and not item.position) then
        _199_ = 1
      else
        _199_ = nil
      end
      return t_5_auto:insert({session_id = session_id, file_path = item.path, line_start = line, line_end = line, anchor_commit = commit_id, status = "open", type = _197_, kind = "review", gh_outdated = _199_, created_by = M["with-gh-user"](login)})
    end
    ok_6_auto, result_7_auto = pcall(_196_)
    local tgt_201_ = require("codeboomer.config")
    if (tgt_201_)["debug?"](tgt_201_) then
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
      local function _203_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _203_)
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
    local function _206_()
      return t_5_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](login), body = sql_literal(item.body), source = "github", commit_id = commit_id, gh_comment_id = tostring(item.id)})
    end
    ok_6_auto, result_7_auto = pcall(_206_)
    local tgt_207_ = require("codeboomer.config")
    if (tgt_207_)["debug?"](tgt_207_) then
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
      local function _209_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _209_)
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
  local function _212_()
    local function _214_()
      local t_213_ = item
      if (nil ~= t_213_) then
        t_213_ = t_213_.user
      else
      end
      if (nil ~= t_213_) then
        t_213_ = t_213_.login
      else
      end
      return t_213_
    end
    return t_5_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](_214_()), body = sql_literal(item.body), source = "github", commit_id = with_commit(with_repo(), item.commit_id), gh_comment_id = tostring(item.id)})
  end
  ok_6_auto, result_7_auto = pcall(_212_)
  local tgt_217_ = require("codeboomer.config")
  if (tgt_217_)["debug?"](tgt_217_) then
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
    local function _219_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _219_)
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
  local t_224_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _225_()
      return t_5_auto:get({where = {id = (id or 0)}})
    end
    ok_6_auto, result_7_auto = pcall(_225_)
    local tgt_226_ = require("codeboomer.config")
    if (tgt_226_)["debug?"](tgt_226_) then
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
      local function _228_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _228_)
    else
    end
    if ok_6_auto then
      t_224_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_224_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_224_) then
    t_224_ = t_224_[1]
  else
  end
  return t_224_
end
local function root_of(t)
  local _232_
  if t.parent_id then
    _232_ = thread_by_id(t.parent_id)
  else
    _232_ = nil
  end
  return (_232_ or t)
end
local function twin_of(t)
  local root = root_of(t)
  if ((root.id or 0) == (t.id or 0)) then
    local t_234_
    local function _236_()
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _235_()
        return t_5_auto:get({where = {parent_id = (t.id or 0)}})
      end
      ok_6_auto, result_7_auto = pcall(_235_)
      local tgt_237_ = require("codeboomer.config")
      if (tgt_237_)["debug?"](tgt_237_) then
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
        local function _239_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _239_)
      else
      end
      if ok_6_auto then
        return result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        return error(result_7_auto, 0)
      end
    end
    t_234_ = sqlite["active-rows"](_236_())
    if (nil ~= t_234_) then
      t_234_ = t_234_[1]
    else
    end
    return t_234_
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
    local function _245_()
      if (twin and ((twin.id or 0) ~= (root.id or 0))) then
        return M["comments-for"](twin.id)
      else
        return {}
      end
    end
    rows = vim.list_extend(M["comments-for"]((root.id or 0)), _245_())
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
        local function _247_()
          local function _249_()
            local t_248_ = session_repo(t.session_id)
            if (nil ~= t_248_) then
              t_248_ = t_248_.path
            else
            end
            return t_248_
          end
          return t_5_auto:insert({session_id = t.session_id, file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = t.anchor_commit, status = "open", type = (t.type or "line"), kind = "local", parent_id = t.id, created_by = with_user(_249_())})
        end
        ok_6_auto, result_7_auto = pcall(_247_)
        local tgt_251_ = require("codeboomer.config")
        if (tgt_251_)["debug?"](tgt_251_) then
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
          local function _253_()
            vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
            st_2_auto.queries["sqlite.thread"] = nil
            return nil
          end
          st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _253_)
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
  local function _258_(msg, level)
    vim.notify(msg, level)
    return nil
  end
  refuse = _258_
  if not t then
    return refuse(("codeboomer: no thread #" .. tostring((thread_id or 0))), vim.log.levels.ERROR)
  elseif ("review" == (t.kind or "local")) then
    return refuse("codeboomer: this thread is already a review thread", vim.log.levels.WARN)
  elseif twin_of(t) then
    return refuse(string.format("codeboomer: thread #%d already promoted", (t.id or 0)), vim.log.levels.WARN)
  elseif ("" == vim.trim((body or ""))) then
    return refuse("codeboomer: empty promotion ignored", vim.log.levels.WARN)
  else
    local repo = session_repo(t.session_id)
    local me
    local function _260_()
      local t_259_ = repo
      if (nil ~= t_259_) then
        t_259_ = t_259_.path
      else
      end
      return t_259_
    end
    me = with_user(_260_())
    local commit_id
    local _263_
    do
      local t_262_ = repo
      if (nil ~= t_262_) then
        t_262_ = t_262_.id
      else
      end
      _263_ = t_262_
    end
    commit_id = with_commit(_263_, (_3fanchor_sha or M["commit-sha"](t.anchor_commit)))
    local twin_id
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _265_()
        return t_5_auto:insert({session_id = (_3fsession_id or t.session_id), file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = commit_id, status = "open", type = (t.type or "line"), kind = "review", parent_id = t.id, created_by = me})
      end
      ok_6_auto, result_7_auto = pcall(_265_)
      local tgt_266_ = require("codeboomer.config")
      if (tgt_266_)["debug?"](tgt_266_) then
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
        local function _268_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _268_)
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
      local function _271_()
        return t_5_auto:insert({thread_id = twin_id, author_id = me, body = sql_literal(body), source = "user", commit_id = commit_id})
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
  local function _278_()
    return t_5_auto:update({set = {body = sql_literal(body)}, where = {id = (comment_id or 0)}})
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
M["stamp-gh-comment"] = function(comment_id, gh_id)
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _284_()
    return t_5_auto:update({set = {gh_comment_id = tostring(gh_id)}, where = {id = (comment_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_284_)
  local tgt_285_ = require("codeboomer.config")
  if (tgt_285_)["debug?"](tgt_285_) then
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
    local function _287_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _287_)
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
  local _290_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _291_()
      return t_5_auto:get({where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_291_)
    local tgt_292_ = require("codeboomer.config")
    if (tgt_292_)["debug?"](tgt_292_) then
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
      local function _294_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _294_)
    else
    end
    if ok_6_auto then
      _290_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _290_ = error(result_7_auto, 0)
    end
  end
  rows = (_290_ or {})
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
      local function _298_()
        return t_5_auto:insert({thread_id = target.id, author_id = with_agent_user(), body = sql_literal(body), source = "agent", commit_id = target.anchor_commit})
      end
      ok_6_auto, result_7_auto = pcall(_298_)
      local tgt_299_ = require("codeboomer.config")
      if (tgt_299_)["debug?"](tgt_299_) then
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
        local function _301_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _301_)
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
  local _306_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _307_()
      return t_5_auto:get({where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_307_)
    local tgt_308_ = require("codeboomer.config")
    if (tgt_308_)["debug?"](tgt_308_) then
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
      local function _310_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _310_)
    else
    end
    if ok_6_auto then
      _306_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _306_ = error(result_7_auto, 0)
    end
  end
  rows = (_306_ or {})
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
    local function _313_()
      local function _315_()
        local t_314_ = session_repo(thread.session_id)
        if (nil ~= t_314_) then
          t_314_ = t_314_.path
        else
        end
        return t_314_
      end
      return t_5_auto:insert({thread_id = thread_id, author_id = with_user(_315_()), body = sql_literal(body), source = "user", commit_id = thread.anchor_commit})
    end
    ok_6_auto, result_7_auto = pcall(_313_)
    local tgt_317_ = require("codeboomer.config")
    if (tgt_317_)["debug?"](tgt_317_) then
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
      local function _319_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _319_)
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
    local function _323_()
      return t_5_auto:update({set = {status = "resolved"}, where = {id = thread_id}})
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
    local function _330_()
      return t_5_auto:update({set = {status = "resolved"}, where = {id = twin.id}})
    end
    ok_6_auto, result_7_auto = pcall(_330_)
    local tgt_331_ = require("codeboomer.config")
    if (tgt_331_)["debug?"](tgt_331_) then
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
      local function _333_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _333_)
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
  local t_337_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.commit(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _338_()
      return t_5_auto:get({where = {id = commit_id}})
    end
    ok_6_auto, result_7_auto = pcall(_338_)
    local tgt_339_ = require("codeboomer.config")
    if (tgt_339_)["debug?"](tgt_339_) then
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
      local function _341_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.commit"]) .. " " .. "sqlite.commit"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.commit"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.commit"] = vim_1_auto.fn.timer_start(1000, _341_)
    else
    end
    if ok_6_auto then
      t_337_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_337_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_337_) then
    t_337_ = t_337_[1]
  else
  end
  if (nil ~= t_337_) then
    t_337_ = t_337_.hash
  else
  end
  return t_337_
end
local function mine_unflagged_3f(c, me, flag)
  return (((c.author_id or 0) == me) and ((c.source or "user") == "user") and (0 == (c[flag] or 0)) and ("" ~= (c.body or "")))
end
M["unposted-user-comments"] = function(thread_id)
  local me
  local function _347_()
    local t_346_
    local function _349_()
      local t_348_ = thread_by_id(thread_id)
      if (nil ~= t_348_) then
        t_348_ = t_348_.session_id
      else
      end
      return t_348_
    end
    t_346_ = session_repo(_349_())
    if (nil ~= t_346_) then
      t_346_ = t_346_.path
    else
    end
    return t_346_
  end
  me = with_user(_347_())
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
    local function _355_()
      local t_354_ = session_repo(session_id)
      if (nil ~= t_354_) then
        t_354_ = t_354_.path
      else
      end
      return t_354_
    end
    me = with_user(_355_())
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
    local function _360_()
      local t_359_ = session_repo(session_id)
      if (nil ~= t_359_) then
        t_359_ = t_359_.path
      else
      end
      return t_359_
    end
    me = with_user(_360_())
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
    local function _364_()
      local function _365_(d)
        for _, id in ipairs(ids) do
          d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
        end
        return nil
      end
      return db_mod_8_auto["get-db"]():with_open(_365_)
    end
    ok_9_auto, result_10_auto = pcall(_364_)
    local tgt_366_ = require("codeboomer.config")
    if (tgt_366_)["debug?"](tgt_366_) then
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
    local t_370_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _371_()
        return t_5_auto:get({where = {id = (comment_id or 0)}})
      end
      ok_6_auto, result_7_auto = pcall(_371_)
      local tgt_372_ = require("codeboomer.config")
      if (tgt_372_)["debug?"](tgt_372_) then
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
        local function _374_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _374_)
      else
      end
      if ok_6_auto then
        t_370_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_370_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_370_) then
      t_370_ = t_370_[1]
    else
    end
    c = t_370_
  end
  if (c and ("user" == (c.source or "user")) and (0 == (c.sent or 0)) and (0 == (c.posted or 0)) and not c.gh_comment_id) then
    do
      local db_mod_8_auto = require("codeboomer.singleton")
      local ok_9_auto, result_10_auto
      local function _378_()
        local function _379_(d)
          return d:execute(string.format("delete from comment where id = %d", (c.id or 0)))
        end
        return db_mod_8_auto["get-db"]():with_open(_379_)
      end
      ok_9_auto, result_10_auto = pcall(_378_)
      local tgt_380_ = require("codeboomer.config")
      if (tgt_380_)["debug?"](tgt_380_) then
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
    local _385_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _386_()
        return t_5_auto:get({where = {session_id = session_id}})
      end
      ok_6_auto, result_7_auto = pcall(_386_)
      local tgt_387_ = require("codeboomer.config")
      if (tgt_387_)["debug?"](tgt_387_) then
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
        local function _389_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _389_)
      else
      end
      if ok_6_auto then
        _385_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        _385_ = error(result_7_auto, 0)
      end
    end
    rows = unresolved_rows(sqlite["active-rows"]((_385_ or {})))
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
    local _394_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _395_()
        return t_5_auto:get({where = {session_id = session_id, kind = "review"}})
      end
      ok_6_auto, result_7_auto = pcall(_395_)
      local tgt_396_ = require("codeboomer.config")
      if (tgt_396_)["debug?"](tgt_396_) then
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
        local function _398_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _398_)
      else
      end
      if ok_6_auto then
        _394_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        _394_ = error(result_7_auto, 0)
      end
    end
    rows = unresolved_rows(sqlite["active-rows"]((_394_ or {})))
    table.sort(rows, by_file_then_line)
    return rows
  end
end
M["comments-for"] = function(thread_id)
  local rows
  local _402_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _403_()
      return t_5_auto:get({where = {thread_id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_403_)
    local tgt_404_ = require("codeboomer.config")
    if (tgt_404_)["debug?"](tgt_404_) then
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
      local function _406_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _406_)
    else
    end
    if ok_6_auto then
      _402_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _402_ = error(result_7_auto, 0)
    end
  end
  rows = sqlite["active-rows"]((_402_ or {}))
  table.sort(rows, by_created)
  return rows
end
M["comment-author"] = function(c)
  local t_409_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _410_()
      return t_5_auto:get({where = {id = (c.author_id or 0)}})
    end
    ok_6_auto, result_7_auto = pcall(_410_)
    local tgt_411_ = require("codeboomer.config")
    if (tgt_411_)["debug?"](tgt_411_) then
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
      local function _413_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _413_)
    else
    end
    if ok_6_auto then
      t_409_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_409_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_409_) then
    t_409_ = t_409_[1]
  else
  end
  return t_409_
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
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _419_()
      return t_5_auto:update({set = {deleted_at = os.time()}, where = {id = (session_id or 0)}})
    end
    ok_6_auto, result_7_auto = pcall(_419_)
    local tgt_420_ = require("codeboomer.config")
    if (tgt_420_)["debug?"](tgt_420_) then
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
      local function _422_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.session"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _422_)
    else
    end
    if ok_6_auto then
    else
      db_mod_4_auto["reset-db"]()
      error(result_7_auto, 0)
    end
  end
  local db_mod_8_auto = require("codeboomer.singleton")
  local ok_9_auto, result_10_auto
  local function _425_()
    local function _426_(d)
      return d:execute(string.format("update comment set gh_comment_id = null\n                                             where thread_id in (select id from comment_thread\n                                                                 where session_id = %d)", (session_id or 0)))
    end
    return db_mod_8_auto["get-db"]():with_open(_426_)
  end
  ok_9_auto, result_10_auto = pcall(_425_)
  local tgt_427_ = require("codeboomer.config")
  if (tgt_427_)["debug?"](tgt_427_) then
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
