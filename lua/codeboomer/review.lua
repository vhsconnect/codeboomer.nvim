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
      do
        local db_mod_4_auto = require("codeboomer.singleton")
        local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
        local ok_6_auto, result_7_auto
        local function _123_()
          return t_5_auto:get({where = {repo_id = repo_id, branch = branch}})
        end
        ok_6_auto, result_7_auto = pcall(_123_)
        local tgt_124_ = require("codeboomer.config")
        if (tgt_124_)["debug?"](tgt_124_) then
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
          local function _126_()
            vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
            st_2_auto.queries["sqlite.session"] = nil
            return nil
          end
          st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _126_)
        else
        end
        if ok_6_auto then
          t_122_ = result_7_auto
        else
          db_mod_4_auto["reset-db"]()
          t_122_ = error(result_7_auto, 0)
        end
      end
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
  local function _132_()
    return t_5_auto:insert({branch = git["branch-name"](), repo_id = with_repo()})
  end
  ok_6_auto, result_7_auto = pcall(_132_)
  local tgt_133_ = require("codeboomer.config")
  if (tgt_133_)["debug?"](tgt_133_) then
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
    local function _135_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.session"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _135_)
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
  local _139_
  do
    local t_138_ = M["session-for"]()
    if (nil ~= t_138_) then
      t_138_ = t_138_.id
    else
    end
    _139_ = t_138_
  end
  local or_141_ = _139_
  if not or_141_ then
    if (git["repo-root"]() and git["branch-name"]()) then
      or_141_ = create_session()
    else
      or_141_ = nil
    end
  end
  return or_141_
end
M["set-session-pr"] = function(session_id, pr_number)
  local db_mod_4_auto = require("codeboomer.singleton")
  local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
  local ok_6_auto, result_7_auto
  local function _143_()
    return t_5_auto:update({set = {pr_number = pr_number}, where = {id = (session_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_143_)
  local tgt_144_ = require("codeboomer.config")
  if (tgt_144_)["debug?"](tgt_144_) then
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
    local function _146_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.session"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _146_)
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
    local t_149_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.session(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _150_()
        return t_5_auto:get({where = {id = id}})
      end
      ok_6_auto, result_7_auto = pcall(_150_)
      local tgt_151_ = require("codeboomer.config")
      if (tgt_151_)["debug?"](tgt_151_) then
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
        local function _153_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.session"]) .. " " .. "sqlite.session"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.session"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.session"] = vim_1_auto.fn.timer_start(1000, _153_)
      else
      end
      if ok_6_auto then
        t_149_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_149_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_149_) then
      t_149_ = t_149_[1]
    else
    end
    return t_149_
  else
    return nil
  end
end
M["comment-by-gh"] = function(gh_id)
  if gh_id then
    local t_158_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _159_()
        return t_5_auto:get({where = {gh_comment_id = tostring(gh_id)}})
      end
      ok_6_auto, result_7_auto = pcall(_159_)
      local tgt_160_ = require("codeboomer.config")
      if (tgt_160_)["debug?"](tgt_160_) then
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
        local function _162_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _162_)
      else
      end
      if ok_6_auto then
        t_158_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_158_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_158_) then
      t_158_ = t_158_[1]
    else
    end
    return t_158_
  else
    return nil
  end
end
M["thread-id-for-gh"] = function(gh_id)
  if gh_id then
    local t_167_ = M["comment-by-gh"](gh_id)
    if (nil ~= t_167_) then
      t_167_ = t_167_.thread_id
    else
    end
    return t_167_
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
    local function _170_()
      return t_5_auto:get({where = {email = email}})
    end
    ok_6_auto, result_7_auto = pcall(_170_)
    local tgt_171_ = require("codeboomer.config")
    if (tgt_171_)["debug?"](tgt_171_) then
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
      local function _173_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _173_)
    else
    end
    if ok_6_auto then
      entry_3f = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      entry_3f = error(result_7_auto, 0)
    end
  end
  local _177_
  do
    local t_176_ = entry_3f
    if (nil ~= t_176_) then
      t_176_ = t_176_[1]
    else
    end
    if (nil ~= t_176_) then
      t_176_ = t_176_.id
    else
    end
    _177_ = t_176_
  end
  if _177_ then
    local t_180_ = entry_3f
    if (nil ~= t_180_) then
      t_180_ = t_180_[1]
    else
    end
    if (nil ~= t_180_) then
      t_180_ = t_180_.id
    else
    end
    return t_180_
  else
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _183_()
      return t_5_auto:insert({name = (login or "unknown"), email = email})
    end
    ok_6_auto, result_7_auto = pcall(_183_)
    local tgt_184_ = require("codeboomer.config")
    if (tgt_184_)["debug?"](tgt_184_) then
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
      local function _186_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _186_)
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
    local t_190_ = item
    if (nil ~= t_190_) then
      t_190_ = t_190_.user
    else
    end
    if (nil ~= t_190_) then
      t_190_ = t_190_.login
    else
    end
    login = t_190_
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
    local function _194_()
      local _195_
      if file_3f then
        _195_ = "file"
      else
        _195_ = "line"
      end
      local _197_
      if (not file_3f and not item.position) then
        _197_ = 1
      else
        _197_ = nil
      end
      return t_5_auto:insert({session_id = session_id, file_path = item.path, line_start = line, line_end = line, anchor_commit = commit_id, status = "open", type = _195_, kind = "review", gh_outdated = _197_, created_by = M["with-gh-user"](login)})
    end
    ok_6_auto, result_7_auto = pcall(_194_)
    local tgt_199_ = require("codeboomer.config")
    if (tgt_199_)["debug?"](tgt_199_) then
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
      local function _201_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _201_)
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
    local function _204_()
      return t_5_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](login), body = sql_literal(item.body), source = "github", commit_id = commit_id, gh_comment_id = tostring(item.id)})
    end
    ok_6_auto, result_7_auto = pcall(_204_)
    local tgt_205_ = require("codeboomer.config")
    if (tgt_205_)["debug?"](tgt_205_) then
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
      local function _207_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _207_)
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
  local function _210_()
    local function _212_()
      local t_211_ = item
      if (nil ~= t_211_) then
        t_211_ = t_211_.user
      else
      end
      if (nil ~= t_211_) then
        t_211_ = t_211_.login
      else
      end
      return t_211_
    end
    return t_5_auto:insert({thread_id = thread_id, author_id = M["with-gh-user"](_212_()), body = sql_literal(item.body), source = "github", commit_id = with_commit(with_repo(), item.commit_id), gh_comment_id = tostring(item.id)})
  end
  ok_6_auto, result_7_auto = pcall(_210_)
  local tgt_215_ = require("codeboomer.config")
  if (tgt_215_)["debug?"](tgt_215_) then
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
    local function _217_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _217_)
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
  local t_222_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _223_()
      return t_5_auto:get({where = {id = (id or 0)}})
    end
    ok_6_auto, result_7_auto = pcall(_223_)
    local tgt_224_ = require("codeboomer.config")
    if (tgt_224_)["debug?"](tgt_224_) then
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
      local function _226_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _226_)
    else
    end
    if ok_6_auto then
      t_222_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_222_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_222_) then
    t_222_ = t_222_[1]
  else
  end
  return t_222_
end
local function root_of(t)
  local _230_
  if t.parent_id then
    _230_ = thread_by_id(t.parent_id)
  else
    _230_ = nil
  end
  return (_230_ or t)
end
local function twin_of(t)
  local root = root_of(t)
  if ((root.id or 0) == (t.id or 0)) then
    local t_232_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _233_()
        return t_5_auto:get({where = {parent_id = (t.id or 0)}})
      end
      ok_6_auto, result_7_auto = pcall(_233_)
      local tgt_234_ = require("codeboomer.config")
      if (tgt_234_)["debug?"](tgt_234_) then
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
        local function _236_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _236_)
      else
      end
      if ok_6_auto then
        t_232_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_232_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_232_) then
      t_232_ = t_232_[1]
    else
    end
    return t_232_
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
    local function _242_()
      if (twin and ((twin.id or 0) ~= (root.id or 0))) then
        return M["comments-for"](twin.id)
      else
        return {}
      end
    end
    rows = vim.list_extend(M["comments-for"]((root.id or 0)), _242_())
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
        local function _244_()
          local function _246_()
            local t_245_ = session_repo(t.session_id)
            if (nil ~= t_245_) then
              t_245_ = t_245_.path
            else
            end
            return t_245_
          end
          return t_5_auto:insert({session_id = t.session_id, file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = t.anchor_commit, status = "open", type = (t.type or "line"), kind = "local", parent_id = t.id, created_by = with_user(_246_())})
        end
        ok_6_auto, result_7_auto = pcall(_244_)
        local tgt_248_ = require("codeboomer.config")
        if (tgt_248_)["debug?"](tgt_248_) then
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
          local function _250_()
            vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
            st_2_auto.queries["sqlite.thread"] = nil
            return nil
          end
          st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _250_)
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
  local function _263_(msg, level)
    vim.notify(msg, level)
    return nil
  end
  refuse = _263_
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
    local function _265_()
      local t_264_ = repo
      if (nil ~= t_264_) then
        t_264_ = t_264_.path
      else
      end
      return t_264_
    end
    me = with_user(_265_())
    local commit_id
    local _268_
    do
      local t_267_ = repo
      if (nil ~= t_267_) then
        t_267_ = t_267_.id
      else
      end
      _268_ = t_267_
    end
    commit_id = with_commit(_268_, (_3fanchor_sha or M["commit-sha"](t.anchor_commit)))
    local twin_id
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _270_()
        return t_5_auto:insert({session_id = (_3fsession_id or t.session_id), file_path = t.file_path, line_start = t.line_start, line_end = t.line_end, code_snapshot = sql_literal(t.code_snapshot), anchor_commit = commit_id, status = "open", type = (t.type or "line"), kind = "review", parent_id = t.id, created_by = me})
      end
      ok_6_auto, result_7_auto = pcall(_270_)
      local tgt_271_ = require("codeboomer.config")
      if (tgt_271_)["debug?"](tgt_271_) then
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
        local function _273_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _273_)
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
      local function _276_()
        return t_5_auto:insert({thread_id = twin_id, author_id = me, body = sql_literal(body), source = "user", commit_id = commit_id})
      end
      ok_6_auto, result_7_auto = pcall(_276_)
      local tgt_277_ = require("codeboomer.config")
      if (tgt_277_)["debug?"](tgt_277_) then
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
        local function _279_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _279_)
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
  local function _283_()
    return t_5_auto:update({set = {body = sql_literal(body)}, where = {id = (comment_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_283_)
  local tgt_284_ = require("codeboomer.config")
  if (tgt_284_)["debug?"](tgt_284_) then
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
    local function _286_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _286_)
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
  local function _289_()
    return t_5_auto:update({set = {gh_comment_id = tostring(gh_id)}, where = {id = (comment_id or 0)}})
  end
  ok_6_auto, result_7_auto = pcall(_289_)
  local tgt_290_ = require("codeboomer.config")
  if (tgt_290_)["debug?"](tgt_290_) then
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
    local function _292_()
      vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
      st_2_auto.queries["sqlite.comments"] = nil
      return nil
    end
    st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _292_)
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
  local _295_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _296_()
      return t_5_auto:get({where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_296_)
    local tgt_297_ = require("codeboomer.config")
    if (tgt_297_)["debug?"](tgt_297_) then
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
      local function _299_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _299_)
    else
    end
    if ok_6_auto then
      _295_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _295_ = error(result_7_auto, 0)
    end
  end
  rows = (_295_ or {})
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
      local function _303_()
        return t_5_auto:insert({thread_id = target.id, author_id = with_agent_user(), body = sql_literal(body), source = "agent", commit_id = target.anchor_commit})
      end
      ok_6_auto, result_7_auto = pcall(_303_)
      local tgt_304_ = require("codeboomer.config")
      if (tgt_304_)["debug?"](tgt_304_) then
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
        local function _306_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _306_)
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
  local _311_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _312_()
      return t_5_auto:get({where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_312_)
    local tgt_313_ = require("codeboomer.config")
    if (tgt_313_)["debug?"](tgt_313_) then
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
      local function _315_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _315_)
    else
    end
    if ok_6_auto then
      _311_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _311_ = error(result_7_auto, 0)
    end
  end
  rows = (_311_ or {})
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
    local function _318_()
      local function _320_()
        local t_319_ = session_repo(thread.session_id)
        if (nil ~= t_319_) then
          t_319_ = t_319_.path
        else
        end
        return t_319_
      end
      return t_5_auto:insert({thread_id = thread_id, author_id = with_user(_320_()), body = sql_literal(body), source = "user", commit_id = thread.anchor_commit})
    end
    ok_6_auto, result_7_auto = pcall(_318_)
    local tgt_322_ = require("codeboomer.config")
    if (tgt_322_)["debug?"](tgt_322_) then
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
      local function _324_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _324_)
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
    local function _328_()
      return t_5_auto:update({set = {status = "resolved"}, where = {id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_328_)
    local tgt_329_ = require("codeboomer.config")
    if (tgt_329_)["debug?"](tgt_329_) then
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
      local function _331_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _331_)
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
    local function _335_()
      return t_5_auto:update({set = {status = "resolved"}, where = {id = twin.id}})
    end
    ok_6_auto, result_7_auto = pcall(_335_)
    local tgt_336_ = require("codeboomer.config")
    if (tgt_336_)["debug?"](tgt_336_) then
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
      local function _338_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.thread"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _338_)
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
  local t_342_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.commit(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _343_()
      return t_5_auto:get({where = {id = commit_id}})
    end
    ok_6_auto, result_7_auto = pcall(_343_)
    local tgt_344_ = require("codeboomer.config")
    if (tgt_344_)["debug?"](tgt_344_) then
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
      local function _346_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.commit"]) .. " " .. "sqlite.commit"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.commit"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.commit"] = vim_1_auto.fn.timer_start(1000, _346_)
    else
    end
    if ok_6_auto then
      t_342_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_342_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_342_) then
    t_342_ = t_342_[1]
  else
  end
  if (nil ~= t_342_) then
    t_342_ = t_342_.hash
  else
  end
  return t_342_
end
local function mine_unflagged_3f(c, me, flag)
  return (((c.author_id or 0) == me) and ((c.source or "user") == "user") and (0 == (c[flag] or 0)) and ("" ~= (c.body or "")))
end
M["unposted-user-comments"] = function(thread_id)
  local me
  local function _352_()
    local t_351_
    local function _354_()
      local t_353_ = thread_by_id(thread_id)
      if (nil ~= t_353_) then
        t_353_ = t_353_.session_id
      else
      end
      return t_353_
    end
    t_351_ = session_repo(_354_())
    if (nil ~= t_351_) then
      t_351_ = t_351_.path
    else
    end
    return t_351_
  end
  me = with_user(_352_())
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
    local function _365_()
      local t_364_ = session_repo(session_id)
      if (nil ~= t_364_) then
        t_364_ = t_364_.path
      else
      end
      return t_364_
    end
    me = with_user(_365_())
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
    local function _369_()
      local function _370_(d)
        for _, id in ipairs(ids) do
          d:execute(string.format("update comment set %s = 1 where id = %d", tostring(flag), (id or 0)))
        end
        return nil
      end
      return db_mod_8_auto["get-db"]():with_open(_370_)
    end
    ok_9_auto, result_10_auto = pcall(_369_)
    local tgt_371_ = require("codeboomer.config")
    if (tgt_371_)["debug?"](tgt_371_) then
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
    local t_375_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _376_()
        return t_5_auto:get({where = {id = (comment_id or 0)}})
      end
      ok_6_auto, result_7_auto = pcall(_376_)
      local tgt_377_ = require("codeboomer.config")
      if (tgt_377_)["debug?"](tgt_377_) then
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
        local function _379_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.comments"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _379_)
      else
      end
      if ok_6_auto then
        t_375_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        t_375_ = error(result_7_auto, 0)
      end
    end
    if (nil ~= t_375_) then
      t_375_ = t_375_[1]
    else
    end
    c = t_375_
  end
  if (c and ("user" == (c.source or "user")) and (0 == (c.sent or 0)) and (0 == (c.posted or 0)) and not c.gh_comment_id) then
    do
      local db_mod_8_auto = require("codeboomer.singleton")
      local ok_9_auto, result_10_auto
      local function _383_()
        local function _384_(d)
          return d:execute(string.format("delete from comment where id = %d", (c.id or 0)))
        end
        return db_mod_8_auto["get-db"]():with_open(_384_)
      end
      ok_9_auto, result_10_auto = pcall(_383_)
      local tgt_385_ = require("codeboomer.config")
      if (tgt_385_)["debug?"](tgt_385_) then
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
    local _390_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _391_()
        return t_5_auto:get({where = {session_id = session_id}})
      end
      ok_6_auto, result_7_auto = pcall(_391_)
      local tgt_392_ = require("codeboomer.config")
      if (tgt_392_)["debug?"](tgt_392_) then
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
        local function _394_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _394_)
      else
      end
      if ok_6_auto then
        _390_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        _390_ = error(result_7_auto, 0)
      end
    end
    rows = unresolved_rows((_390_ or {}))
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
    local _399_
    do
      local db_mod_4_auto = require("codeboomer.singleton")
      local t_5_auto = sqlite.thread(db_mod_4_auto["get-db"]())
      local ok_6_auto, result_7_auto
      local function _400_()
        return t_5_auto:get({where = {session_id = session_id, kind = "review"}})
      end
      ok_6_auto, result_7_auto = pcall(_400_)
      local tgt_401_ = require("codeboomer.config")
      if (tgt_401_)["debug?"](tgt_401_) then
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
        local function _403_()
          vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.thread"]) .. " " .. "sqlite.thread"), vim_1_auto.log.levels.INFO)
          st_2_auto.queries["sqlite.thread"] = nil
          return nil
        end
        st_2_auto.timers["sqlite.thread"] = vim_1_auto.fn.timer_start(1000, _403_)
      else
      end
      if ok_6_auto then
        _399_ = result_7_auto
      else
        db_mod_4_auto["reset-db"]()
        _399_ = error(result_7_auto, 0)
      end
    end
    rows = unresolved_rows((_399_ or {}))
    table.sort(rows, by_file_then_line)
    return rows
  end
end
M["comments-for"] = function(thread_id)
  local rows
  local _407_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.comments(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _408_()
      return t_5_auto:get({where = {thread_id = thread_id}})
    end
    ok_6_auto, result_7_auto = pcall(_408_)
    local tgt_409_ = require("codeboomer.config")
    if (tgt_409_)["debug?"](tgt_409_) then
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
      local function _411_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.comments"]) .. " " .. "sqlite.comments"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.comments"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.comments"] = vim_1_auto.fn.timer_start(1000, _411_)
    else
    end
    if ok_6_auto then
      _407_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      _407_ = error(result_7_auto, 0)
    end
  end
  rows = (_407_ or {})
  table.sort(rows, by_created)
  return rows
end
M["comment-author"] = function(c)
  local t_414_
  do
    local db_mod_4_auto = require("codeboomer.singleton")
    local t_5_auto = sqlite.user(db_mod_4_auto["get-db"]())
    local ok_6_auto, result_7_auto
    local function _415_()
      return t_5_auto:get({where = {id = (c.author_id or 0)}})
    end
    ok_6_auto, result_7_auto = pcall(_415_)
    local tgt_416_ = require("codeboomer.config")
    if (tgt_416_)["debug?"](tgt_416_) then
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
      local function _418_()
        vim_1_auto.notify(("querying " .. tostring(st_2_auto.queries["sqlite.user"]) .. " " .. "sqlite.user"), vim_1_auto.log.levels.INFO)
        st_2_auto.queries["sqlite.user"] = nil
        return nil
      end
      st_2_auto.timers["sqlite.user"] = vim_1_auto.fn.timer_start(1000, _418_)
    else
    end
    if ok_6_auto then
      t_414_ = result_7_auto
    else
      db_mod_4_auto["reset-db"]()
      t_414_ = error(result_7_auto, 0)
    end
  end
  if (nil ~= t_414_) then
    t_414_ = t_414_[1]
  else
  end
  return t_414_
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
  local function _425_()
    local function _426_(d)
      return d:execute(string.format("begin;\n                                               delete from comment where thread_id in (%s);\n                                               update comment_thread set parent_id = null\n                                                 where parent_id in (%s) and session_id != %d;\n                                               delete from comment_thread where session_id = %d;\n                                               delete from session where id = %d;\n                                               commit;", threads, threads, (session_id or 0), (session_id or 0), (session_id or 0)))
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
