-- [nfnl] fnl/codeboomer/sidebar.fnl
vim = vim
local review = require("codeboomer.review")
local input = require("codeboomer.input")
local git = require("codeboomer.git")
local github = require("codeboomer.github")
local M = {}
local augroup_name = "codeboomer-review-pane"
local pane_buf_name = "codeboomer://review-comments"
local extmark_ns = vim.api.nvim_create_namespace("codeboomer-review-pane")
local flash_ns = vim.api.nvim_create_namespace("codeboomer-review-flash")
local flash_ms = 2000
local pane_width = 40
local pane_keys_footer = {("\226\148\128\226\148\128 keys " .. string.rep("\226\148\128", (pane_width - 8))), "r reply \194\183 a agent \194\183 p promote", "e edit \194\183 q resolve \194\183 n/N thread"}
local rest_ms = 100
local db_refresh_ms = 5000
local pane_win = nil
local threads_by_path = {}
local all_threads = {}
local timer_id = nil
local db_refresh_timer = nil
local pane_source_win = nil
local pane_path = nil
local pane_threads = nil
local pane_header_rows = {}
local function thread_hl(index)
  local groups = {"Title", "Special", "String", "Function"}
  return groups[(1 + ((index - 1) % #groups))]
end
local function normal_buf(bufnr)
  local _2_
  do
    local t_1_ = vim.bo
    if (nil ~= t_1_) then
      t_1_ = t_1_[bufnr]
    else
    end
    if (nil ~= t_1_) then
      t_1_ = t_1_.buftype
    else
    end
    _2_ = t_1_
  end
  return ("" == (_2_ or ""))
end
local rel_path_cache = {}
local function buf_rel_path(bufnr)
  local or_5_ = rel_path_cache[bufnr]
  if not or_5_ then
    local p = git["rel-path"](vim.api.nvim_buf_get_name(bufnr))
    rel_path_cache[bufnr] = p
    or_5_ = p
  end
  return or_5_
end
local function source_buf_name()
  local in_pane = (pane_win and vim.api.nvim_win_is_valid(pane_win) and (vim.api.nvim_get_current_win() == pane_win))
  local win
  if (in_pane and pane_source_win and vim.api.nvim_win_is_valid(pane_source_win)) then
    win = pane_source_win
  else
    win = vim.api.nvim_get_current_win()
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if normal_buf(buf) then
    return vim.api.nvim_buf_get_name(buf)
  else
    return nil
  end
end
local function source_session()
  local name = source_buf_name()
  if name then
    return review["session-for"](name)
  else
    return nil
  end
end
local function _10_()
  local t_11_ = source_session()
  if (nil ~= t_11_) then
    t_11_ = t_11_.id
  else
  end
  return t_11_
end
M["session-id"] = _10_
local function threads_at(path, line)
  local found = nil
  for _, t in ipairs((threads_by_path[path] or {})) do
    if found then break end
    if (t.line_start and t.line_end and (line >= t.line_start) and (line <= t.line_end)) then
      found = t
    else
    end
  end
  if found then
    return {found}
  else
    return {}
  end
end
local function stamp_thread(t)
  local twin = review.twin((t.id or 0))
  if twin then
    t["twin-kind"] = twin.kind
  else
    t["twin-kind"] = nil
  end
  t.conversation = review["conversation-comments"]((t.id or 0))
  for _, c in ipairs((t.conversation or {})) do
    local _17_
    do
      local t_16_ = review["comment-author"](c)
      if (nil ~= t_16_) then
        t_16_ = t_16_.name
      else
      end
      _17_ = t_16_
    end
    c["author-name"] = (_17_ or "unknown")
  end
  if t.anchor_commit then
    t["anchor-sha"] = review["commit-sha"](t.anchor_commit)
  else
    t["anchor-sha"] = nil
  end
  return nil
end
local map_version = 0
local rendered_sig = nil
local function conv_sig(t)
  local sig = ""
  for _, c in ipairs((t.conversation or {})) do
    sig = (sig .. tostring((c.id or 0)) .. ",")
  end
  return sig
end
local function map_sig()
  local sig = ""
  for _, t in ipairs(all_threads) do
    sig = (sig .. tostring((t.id or 0)) .. ":" .. conv_sig(t) .. ";")
  end
  return sig
end
local function short_sha(sha)
  if (sha and (#sha >= 7)) then
    return sha:sub(1, 7)
  else
    return (sha or "?")
  end
end
local function thread_header(base, t)
  local status
  local _21_
  if (t.gh_outdated and ((t.gh_outdated or 0) > 0)) then
    _21_ = ", outdated"
  else
    _21_ = nil
  end
  local _23_
  if ("review" == (t["twin-kind"] or "local")) then
    _23_ = " \194\183 promoted"
  else
    _23_ = nil
  end
  status = ((t.status or "open") .. (_21_ or "") .. (_23_ or ""))
  local pos
  if ("file" == (t.type or "line")) then
    pos = "file"
  else
    pos = ((t.line_start or "?") .. "-" .. (t.line_end or "?"))
  end
  return string.format("#%d  %s:%s  (%s)  anchor %s", (t.id or 0), base, pos, status, short_sha(t["anchor-sha"]))
end
local function comment_label(c)
  return string.format("[%s] %s", (c.source or "user"), (c["author-name"] or "unknown"))
end
local function render(path, threads)
  local lines = {}
  local headers = {}
  local labels = {}
  local base = (vim.fs.basename((path or "")) or "?")
  for i, t in ipairs(threads) do
    if (i > 1) then
      table.insert(lines, string.rep("\226\148\128", pane_width))
    else
    end
    table.insert(headers, {row = (#lines + 1), hl = thread_hl((t["hl-index"] or i)), thread = t})
    table.insert(lines, thread_header(base, t))
    table.insert(lines, "")
    for j, c in ipairs((t.conversation or {})) do
      if (j > 1) then
        table.insert(lines, "")
      else
      end
      table.insert(labels, {row = (#lines + 1)})
      table.insert(lines, comment_label(c))
      for _, l in ipairs(vim.split((c.body or ""), "\n")) do
        table.insert(lines, l)
      end
    end
  end
  if (#threads > 0) then
    table.insert(lines, "")
    for _, l in ipairs(pane_keys_footer) do
      table.insert(labels, {row = (#lines + 1)})
      table.insert(lines, l)
    end
  else
  end
  return {lines = lines, headers = headers, labels = labels}
end
local function pane_sig(path, threads)
  local _29_
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, t in ipairs((threads or {})) do
      local val_28_ = tostring((t.id or 0))
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    _29_ = tbl_26_
  end
  return ((path or "") .. "|" .. tostring(map_version) .. "|" .. table.concat(_29_, ","))
end
local function render_pane(path, threads)
  if (pane_sig(path, threads) ~= rendered_sig) then
    rendered_sig = pane_sig(path, threads)
    local buf = vim.api.nvim_win_get_buf(pane_win)
    local bo = vim.bo[buf]
    local _let_31_ = render(path, threads)
    local lines = _let_31_.lines
    local headers = _let_31_.headers
    local labels = _let_31_.labels
    pane_path = path
    pane_threads = threads
    pane_header_rows = headers
    vim.api.nvim_buf_clear_namespace(buf, extmark_ns, 0, -1)
    bo.modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    bo.modifiable = false
    for _, h in ipairs(headers) do
      vim.api.nvim_buf_set_extmark(buf, extmark_ns, (h.row - 1), 0, {line_hl_group = h.hl})
    end
    for _, l in ipairs(labels) do
      vim.api.nvim_buf_set_extmark(buf, extmark_ns, (l.row - 1), 0, {line_hl_group = "Comment"})
    end
    return nil
  else
    return nil
  end
end
local function pane_thread_at(row)
  local t = nil
  for _, h in ipairs(pane_header_rows) do
    if (h.row > row) then break end
    t = h.thread
  end
  return t
end
local function refresh_pane()
  if (pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    for _, t in ipairs((pane_threads or {})) do
      stamp_thread(t)
    end
    map_version = (1 + map_version)
    return render_pane(pane_path, pane_threads)
  else
    return nil
  end
end
local function review_half(t)
  if ("review" == (t.kind or "local")) then
    return t
  else
    local twin = review.twin((t.id or 0))
    if (twin and ("review" == (twin.kind or "local"))) then
      return twin
    else
      return nil
    end
  end
end
local function pane_reply()
  local t
  local function _37_()
    local t_36_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_36_) then
      t_36_ = t_36_[1]
    else
    end
    return t_36_
  end
  t = pane_thread_at(_37_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local target = review_half(t)
    if not target then
      return vim.notify("codeboomer: thread not promoted \226\128\148 p promotes it first", vim.log.levels.WARN)
    else
      local function _39_(lines)
        if review["user-reply"]((target.id or 0), table.concat(lines, "\n")) then
          return refresh_pane()
        else
          return nil
        end
      end
      return input.open({title = string.format(" Reply on thread #%d> ", (t.id or 0)), ["on-submit"] = _39_})
    end
  end
end
local function pane_agent_reply()
  local t
  local function _44_()
    local t_43_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_43_) then
      t_43_ = t_43_[1]
    else
    end
    return t_43_
  end
  t = pane_thread_at(_44_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local target
    if ("local" == (t.kind or "local")) then
      target = t
    else
      target = (review.twin((t.id or 0)) or review["ensure-local-twin"]((t.id or 0)))
    end
    if not target then
      return vim.notify("codeboomer: could not open the conversation", vim.log.levels.ERROR)
    else
      local function _47_(lines)
        if review["user-reply"]((target.id or 0), table.concat(lines, "\n")) then
          return refresh_pane()
        else
          return nil
        end
      end
      return input.open({title = string.format(" Reply to the agent on thread #%d> ", (t.id or 0)), ["on-submit"] = _47_})
    end
  end
end
local function virgin_body(t)
  local cs = review["conversation-comments"]((t.id or 0))
  if (1 == #cs) then
    local c = cs[1]
    if ("user" == (c.source or "user")) then
      return (c.body or "")
    else
      return nil
    end
  else
    return nil
  end
end
local function first_user_body(t)
  local body = nil
  for _, c in ipairs(review["conversation-comments"]((t.id or 0))) do
    local or_53_ = body
    if not or_53_ then
      if ("user" == (c.source or "user")) then
        or_53_ = (c.body or "")
      else
        or_53_ = nil
      end
    end
    body = or_53_
  end
  return body
end
local function pane_promote()
  local t
  local function _56_()
    local t_55_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_55_) then
      t_55_ = t_55_[1]
    else
    end
    return t_55_
  end
  t = pane_thread_at(_56_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  elseif ("review" == (t.kind or "local")) then
    return vim.notify("codeboomer: this thread is already on github", vim.log.levels.WARN)
  elseif review.twin((t.id or 0)) then
    return vim.notify(string.format("codeboomer: thread #%d already promoted", (t.id or 0)), vim.log.levels.WARN)
  else
    local session = source_session()
    local ctx = require("codeboomer.review-mode")["promote-context"](session)
    if not ctx then
      return vim.notify("codeboomer: this branch's session is not bound to a PR \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
    elseif (ctx["head-ranges"] and github["thread-off-diff"](t, ctx["head-ranges"])) then
      return vim.notify("codeboomer: the range falls outside the PR diff \226\128\148 move or resolve the thread first", vim.log.levels.ERROR)
    else
      local as_is = virgin_body(t)
      if as_is then
        review.promote((t.id or 0), as_is, ctx["session-id"])
        refresh_pane()
        return vim.notify(string.format("codeboomer: thread #%d promoted", (t.id or 0)), vim.log.levels.INFO)
      else
        local function _58_(lines)
          local body = table.concat(lines, "\n")
          if ("" ~= vim.trim(body)) then
            review.promote((t.id or 0), body, ctx["session-id"])
            refresh_pane()
            return vim.notify(string.format("codeboomer: thread #%d promoted", (t.id or 0)), vim.log.levels.INFO)
          else
            return nil
          end
        end
        return input.open({title = string.format(" Promote thread #%d> ", (t.id or 0)), prefill = (first_user_body(t) or ""), ["on-submit"] = _58_})
      end
    end
  end
end
local function pane_edit()
  local t
  local function _64_()
    local t_63_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_63_) then
      t_63_ = t_63_[1]
    else
    end
    return t_63_
  end
  t = pane_thread_at(_64_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local target = review_half(t)
    if not target then
      return vim.notify("codeboomer: thread not promoted \226\128\148 p promotes it first", vim.log.levels.WARN)
    else
      local c = review["unposted-user-comments"]((target.id or 0))[1]
      if not c then
        return vim.notify("codeboomer: nothing unposted to edit", vim.log.levels.WARN)
      else
        local function _66_(lines)
          review["update-comment-body"]((c.id or 0), table.concat(lines, "\n"))
          return refresh_pane()
        end
        return input.open({title = string.format(" Edit comment #%d> ", (c.id or 0)), prefill = (c.body or ""), ["on-submit"] = _66_})
      end
    end
  end
end
local function covering_at_source()
  if not (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win) and pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    return nil
  else
    local row
    do
      local t_70_ = vim.api.nvim_win_get_cursor(pane_source_win)
      if (nil ~= t_70_) then
        t_70_ = t_70_[1]
      else
      end
      row = t_70_
    end
    return threads_at((pane_path or ""), (row or 0))
  end
end
local function pane_resolve()
  local t
  local function _74_()
    local t_73_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_73_) then
      t_73_ = t_73_[1]
    else
    end
    return t_73_
  end
  t = pane_thread_at(_74_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local remaining
    do
      review["resolve-thread"]((t.id or 0))
      M["reload-threads"]()
      remaining = covering_at_source()
    end
    if remaining then
      return render_pane(pane_path, remaining)
    else
      return nil
    end
  end
end
local pane_jump = nil
local function hide_pane()
  local win = pane_win
  pane_win = nil
  rendered_sig = nil
  if (win and vim.api.nvim_win_is_valid(win)) then
    return pcall(vim.api.nvim_win_close, win, true)
  else
    return nil
  end
end
local function show_pane(path, threads)
  if (pane_win and vim.api.nvim_win_is_valid(pane_win) and (vim.api.nvim_win_get_tabpage(pane_win) ~= vim.api.nvim_get_current_tabpage())) then
    hide_pane()
  else
  end
  if not (pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    vim.cmd(string.format("botright %dvnew", pane_width))
    pane_win = vim.api.nvim_get_current_win()
    do
      local buf = vim.api.nvim_get_current_buf()
      local bo = vim.bo[buf]
      local wo = vim.wo[pane_win]
      bo.buftype = "nofile"
      bo.swapfile = false
      bo.bufhidden = "wipe"
      bo.modifiable = false
      pcall(vim.api.nvim_buf_set_name, buf, pane_buf_name)
      wo.wrap = true
      wo.linebreak = true
      wo.number = false
      wo.relativenumber = false
      wo.signcolumn = "no"
      wo.winfixwidth = true
      vim.keymap.set("n", "r", pane_reply, {buffer = buf, desc = "codeboomer: reply on this thread"})
      vim.keymap.set("n", "a", pane_agent_reply, {buffer = buf, desc = "codeboomer: reply to the agent on this thread"})
      vim.keymap.set("n", "p", pane_promote, {buffer = buf, desc = "codeboomer: promote this thread to the PR review"})
      vim.keymap.set("n", "e", pane_edit, {buffer = buf, desc = "codeboomer: edit the promoted comment"})
      vim.keymap.set("n", "q", pane_resolve, {buffer = buf, desc = "codeboomer: resolve this thread"})
      local function _80_()
        return pane_jump(1)
      end
      vim.keymap.set("n", "n", _80_, {buffer = buf, desc = "codeboomer: jump to the next thread"})
      local function _81_()
        return pane_jump(-1)
      end
      vim.keymap.set("n", "N", _81_, {buffer = buf, desc = "codeboomer: jump to the previous thread"})
    end
    vim.cmd("wincmd p")
  else
  end
  return render_pane(path, threads)
end
local function _83_(bufnr)
  if (vim.api.nvim_buf_is_valid(bufnr) and normal_buf(bufnr)) then
    local path = buf_rel_path(bufnr)
    local threads = (threads_by_path[path] or {})
    if ((#threads > 0) and (not pane_win or not vim.api.nvim_win_is_valid(pane_win) or (path ~= pane_path))) then
      pane_source_win = vim.api.nvim_get_current_win()
      return show_pane(path, threads)
    else
      return nil
    end
  else
    return nil
  end
end
M["enter-file"] = _83_
local function flash_line(win, row)
  local buf = vim.api.nvim_win_get_buf(win)
  local id = vim.api.nvim_buf_set_extmark(buf, flash_ns, (row - 1), 0, {end_row = row, hl_group = "IncSearch", hl_eol = true})
  local function _86_()
    if vim.api.nvim_buf_is_valid(buf) then
      return pcall(vim.api.nvim_buf_del_extmark, buf, flash_ns, id)
    else
      return nil
    end
  end
  return vim.defer_fn(_86_, flash_ms)
end
local function _88_(dir)
  if not (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win)) then
    return vim.notify("codeboomer: the pane has no code window to jump from", vim.log.levels.WARN)
  else
    local n = #all_threads
    if (0 == n) then
      return vim.notify("codeboomer: no threads to jump to", vim.log.levels.WARN)
    else
      local t
      local function _90_()
        local t_89_ = vim.api.nvim_win_get_cursor(pane_win)
        if (nil ~= t_89_) then
          t_89_ = t_89_[1]
        else
        end
        return t_89_
      end
      t = pane_thread_at(_90_())
      local idx
      do
        local found = nil
        for i, th in ipairs(all_threads) do
          if (t and (th.id == t.id)) then
            found = (i - 1)
          else
            found = found
          end
        end
        idx = found
      end
      local target0
      local or_93_ = idx
      if not or_93_ then
        if (dir > 0) then
          or_93_ = -1
        else
          or_93_ = 0
        end
      end
      target0 = ((or_93_ + dir) % n)
      local target = all_threads[(target0 + 1)]
      local cur_path = buf_rel_path(vim.api.nvim_win_get_buf(pane_source_win))
      local target_path = ((git["repo-root"]() or "") .. "/" .. target.file_path)
      do
        local jump_to
        local function _95_()
          if (cur_path ~= target.file_path) then
            vim.cmd({cmd = "edit", args = {target_path}})
          else
          end
          local row = math.min((target.line_start or 1), vim.api.nvim_buf_line_count(0))
          vim.api.nvim_win_set_cursor(pane_source_win, {row, 0})
          vim.cmd("normal! zz")
          return row
        end
        jump_to = _95_
        local row = vim.api.nvim_win_call(pane_source_win, jump_to)
        flash_line(pane_source_win, row)
      end
      show_pane(target.file_path, {target})
      return vim.api.nvim_win_set_cursor(pane_win, {1, 0})
    end
  end
end
pane_jump = _88_
local function evaluate_at(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if normal_buf(buf) then
    local row
    do
      local t_99_ = vim.api.nvim_win_get_cursor(win)
      if (nil ~= t_99_) then
        t_99_ = t_99_[1]
      else
      end
      row = t_99_
    end
    local path = buf_rel_path(buf)
    local threads = threads_at(path, (row or 0))
    if (#threads > 0) then
      pane_source_win = win
      return show_pane(path, threads)
    else
      return nil
    end
  else
    return nil
  end
end
local function check_now()
  local win = vim.api.nvim_get_current_win()
  if (win == pane_win) then
    if (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win)) then
      return evaluate_at(pane_source_win)
    else
      return nil
    end
  else
    local _105_
    do
      local t_104_ = vim.api.nvim_win_get_config(win)
      if (nil ~= t_104_) then
        t_104_ = t_104_.relative
      else
      end
      _105_ = t_104_
    end
    if ("" == (_105_ or "")) then
      return evaluate_at(win)
    else
      return nil
    end
  end
end
local function schedule_check()
  if timer_id then
    vim.fn.timer_stop(timer_id)
  else
  end
  timer_id = vim.fn.timer_start(rest_ms, check_now)
  return nil
end
local function idle_refresh()
  if M["session-id"]() then
    return M["reload-threads"]()
  else
    return nil
  end
end
local function schedule_db_refresh()
  if db_refresh_timer then
    vim.fn.timer_stop(db_refresh_timer)
  else
  end
  db_refresh_timer = vim.fn.timer_start(db_refresh_ms, idle_refresh)
  return nil
end
local function pane_threads_fresh()
  local live = (threads_by_path[(pane_path or "")] or {})
  local by_id
  do
    local tbl_21_ = {}
    for _, t in ipairs(live) do
      local k_22_, v_23_ = t.id, t
      if ((k_22_ ~= nil) and (v_23_ ~= nil)) then
        tbl_21_[k_22_] = v_23_
      else
      end
    end
    by_id = tbl_21_
  end
  local tbl_26_ = {}
  local i_27_ = 0
  for _, t in ipairs((pane_threads or {})) do
    local val_28_ = by_id[(t.id or 0)]
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local loaded_session_id = nil
local function maybe_reload_session()
  local sid = M["session-id"]()
  if (sid ~= loaded_session_id) then
    return M["reload-threads"]()
  else
    return nil
  end
end
M["reload-threads"] = function()
  local sid = M["session-id"]()
  local before = map_sig()
  loaded_session_id = sid
  threads_by_path = {}
  if sid then
    all_threads = review["threads-for-session"](sid)
  else
    all_threads = {}
  end
  for _, t in ipairs(all_threads) do
    stamp_thread(t)
  end
  for _, t in ipairs(all_threads) do
    local path = (t.file_path or "")
    local peers = vim.list_extend((threads_by_path[path] or {}), {t})
    t["hl-index"] = #peers
    threads_by_path[path] = peers
  end
  if (before ~= map_sig()) then
    map_version = (1 + map_version)
    if (pane_win and vim.api.nvim_win_is_valid(pane_win)) then
      render_pane(pane_path, pane_threads_fresh())
    else
    end
    return schedule_check()
  else
    return nil
  end
end
local function attach_autocmds()
  vim.api.nvim_create_augroup(augroup_name, {clear = true})
  local function _118_(ev)
    maybe_reload_session()
    M["enter-file"](ev.buf)
    schedule_check()
    return schedule_db_refresh()
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = augroup_name, callback = _118_})
  local function _119_()
    schedule_check()
    return schedule_db_refresh()
  end
  vim.api.nvim_create_autocmd({"WinEnter", "TabEnter", "CursorMoved", "CursorMovedI", "FocusGained"}, {group = augroup_name, callback = _119_})
  local function _120_(ev)
    if (pane_win == tonumber(ev.match)) then
      pane_win = nil
      rendered_sig = nil
      return nil
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {group = augroup_name, callback = _120_})
  return vim.api.nvim_create_autocmd("User", {group = augroup_name, pattern = {"CodeboomerAnnotated", "CodeboomerSessionReset", "CodeboomerImported"}, callback = M["reload-threads"]})
end
local function _122_()
  M["reload-threads"]()
  return check_now()
end
M.open = _122_
attach_autocmds()
return M
