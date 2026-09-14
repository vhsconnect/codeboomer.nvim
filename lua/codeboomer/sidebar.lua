-- [nfnl] fnl/codeboomer/sidebar.fnl
vim = vim
local review = require("codeboomer.review")
local input = require("codeboomer.input")
local git = require("codeboomer.git")
local M = {}
local augroup_name = "codeboomer-review-pane"
local pane_buf_name = "codeboomer://review-comments"
local extmark_ns = vim.api.nvim_create_namespace("codeboomer-review-pane")
local pane_width = 40
local sign_text = "\226\150\140"
local rest_ms = 100
local enabled = false
local sticky = false
local pane_win = nil
local threads_by_path = {}
local timer_id = nil
local pane_source_win = nil
local pane_path = nil
local pane_threads = nil
local pane_header_rows = {}
local function thread_hl(index)
  local groups = {"Title", "Special", "String", "Function"}
  return groups[(1 + ((index - 1) % #groups))]
end
local function place_marks(bufnr, threads)
  if vim.api.nvim_buf_is_valid(bufnr) then
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    local taken = {}
    vim.api.nvim_buf_clear_namespace(bufnr, extmark_ns, 0, -1)
    for i, t in ipairs(threads) do
      local start = (t.line_start or 0)
      local finish = math.min((t.line_end or start), line_count)
      local hl = thread_hl((t["hl-index"] or i))
      for ln = start, finish do
        if not taken[ln] then
          taken[ln] = true
          vim.api.nvim_buf_set_extmark(bufnr, extmark_ns, (ln - 1), 0, {sign_text = sign_text, sign_hl_group = hl})
        else
        end
      end
    end
    return nil
  else
    return nil
  end
end
local function normal_buf(bufnr)
  local _4_
  do
    local t_3_ = vim.bo
    if (nil ~= t_3_) then
      t_3_ = t_3_[bufnr]
    else
    end
    if (nil ~= t_3_) then
      t_3_ = t_3_.buftype
    else
    end
    _4_ = t_3_
  end
  return ("" == (_4_ or ""))
end
local function mark_loaded_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if (vim.api.nvim_buf_is_loaded(bufnr) and normal_buf(bufnr)) then
      local path = git["rel-path"](vim.api.nvim_buf_get_name(bufnr))
      place_marks(bufnr, (threads_by_path[path] or {}))
    else
    end
  end
  return nil
end
local function threads_at(path, line)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, t in ipairs((threads_by_path[path] or {})) do
    local val_28_
    if (t.line_start and t.line_end and (line >= t.line_start) and (line <= t.line_end)) then
      val_28_ = t
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
local function thread_header(base, t)
  local status
  if (t.gh_outdated and ((t.gh_outdated or 0) > 0)) then
    status = ((t.status or "open") .. ", outdated")
  else
    status = (t.status or "open")
  end
  return string.format("#%d  %s:%s-%s  (%s)", (t.id or 0), base, (t.line_start or "?"), (t.line_end or "?"), status)
end
local function render(path, threads)
  local lines = {}
  local headers = {}
  local base = (vim.fs.basename((path or "")) or "?")
  for i, t in ipairs(threads) do
    if (i > 1) then
      table.insert(lines, string.rep("\226\148\128", pane_width))
    else
    end
    table.insert(headers, {row = (#lines + 1), hl = thread_hl((t["hl-index"] or i)), thread = t})
    table.insert(lines, thread_header(base, t))
    for _, c in ipairs(review["comments-for"](t.id)) do
      for _0, l in ipairs(vim.split((c.body or ""), "\n")) do
        table.insert(lines, l)
      end
    end
  end
  return {lines = lines, headers = headers}
end
local function render_pane(path, threads)
  local buf = vim.api.nvim_win_get_buf(pane_win)
  local bo = vim.bo[buf]
  local _let_12_ = render(path, threads)
  local lines = _let_12_.lines
  local headers = _let_12_.headers
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
  return nil
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
    return render_pane(pane_path, pane_threads)
  else
    return nil
  end
end
local function pane_reply()
  local t
  local function _15_()
    local t_14_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_14_) then
      t_14_ = t_14_[1]
    else
    end
    return t_14_
  end
  t = pane_thread_at(_15_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local function _17_(lines)
      if review["user-reply"]((t.id or 0), table.concat(lines, "\n")) then
        return refresh_pane()
      else
        return nil
      end
    end
    return input.open({title = string.format(" Reply to thread #%d> ", (t.id or 0)), ["on-submit"] = _17_})
  end
end
local function pane_resolve()
  local t
  local function _21_()
    local t_20_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_20_) then
      t_20_ = t_20_[1]
    else
    end
    return t_20_
  end
  t = pane_thread_at(_21_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    review["resolve-thread"]((t.id or 0))
    return M["reload-threads"]()
  end
end
local function pane_next()
  if not (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win)) then
    return vim.notify("codeboomer: the pane has no code window to jump from", vim.log.levels.WARN)
  else
    local t
    local function _25_()
      local t_24_ = vim.api.nvim_win_get_cursor(pane_win)
      if (nil ~= t_24_) then
        t_24_ = t_24_[1]
      else
      end
      return t_24_
    end
    t = pane_thread_at(_25_())
    local all = (threads_by_path[(pane_path or "")] or {})
    local pos
    if t then
      pos = (t["hl-index"] or 1)
    else
      pos = 0
    end
    local next_t
    do
      local t_28_ = all
      if (nil ~= t_28_) then
        t_28_ = t_28_[(1 + (pos % #all))]
      else
      end
      next_t = t_28_
    end
    local target
    local _31_
    do
      local t_30_ = next_t
      if (nil ~= t_30_) then
        t_30_ = t_30_.line_start
      else
      end
      _31_ = t_30_
    end
    target = (_31_ or 1)
    vim.api.nvim_set_current_win(pane_source_win)
    return vim.api.nvim_win_set_cursor(pane_source_win, {target, 0})
  end
end
local function hide_pane()
  local win = pane_win
  pane_win = nil
  if (win and vim.api.nvim_win_is_valid(win)) then
    return pcall(vim.api.nvim_win_close, win, true)
  else
    return nil
  end
end
local function show_pane(path, threads)
  if (not sticky and pane_win and vim.api.nvim_win_is_valid(pane_win) and (vim.api.nvim_win_get_tabpage(pane_win) ~= vim.api.nvim_get_current_tabpage())) then
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
      vim.keymap.set("n", "r", pane_reply, {buffer = buf, desc = "codeboomer: reply to this thread"})
      vim.keymap.set("n", "q", pane_resolve, {buffer = buf, desc = "codeboomer: resolve this thread"})
      vim.keymap.set("n", "n", pane_next, {buffer = buf, desc = "codeboomer: jump to the next thread"})
    end
    vim.cmd("wincmd p")
  else
  end
  return render_pane(path, threads)
end
local function evaluate_at(win)
  local row
  do
    local t_37_ = vim.api.nvim_win_get_cursor(win)
    if (nil ~= t_37_) then
      t_37_ = t_37_[1]
    else
    end
    row = t_37_
  end
  local path = git["rel-path"](vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)))
  local threads = threads_at(path, (row or 0))
  if (enabled and (#threads > 0)) then
    pane_source_win = win
    return show_pane(path, threads)
  else
    if not sticky then
      return hide_pane()
    else
      return nil
    end
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
    local _43_
    do
      local t_42_ = vim.api.nvim_win_get_config(win)
      if (nil ~= t_42_) then
        t_42_ = t_42_.relative
      else
      end
      _43_ = t_42_
    end
    if ("" == (_43_ or "")) then
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
M["reload-threads"] = function()
  if not review["current-session-id"]() then
    review["adopt-sole-session"]()
  else
  end
  local sid = review["current-session-id"]()
  threads_by_path = {}
  local function _49_()
    if sid then
      return review["threads-for-session"](sid)
    else
      return {}
    end
  end
  for _, t in ipairs(_49_()) do
    local path = (t.file_path or "")
    local peers = vim.list_extend((threads_by_path[path] or {}), {t})
    t["hl-index"] = #peers
    threads_by_path[path] = peers
  end
  mark_loaded_buffers()
  return schedule_check()
end
local function attach_autocmds()
  vim.api.nvim_create_augroup(augroup_name, {clear = true})
  local function _50_()
    if normal_buf(0) then
      local path = git["rel-path"]()
      place_marks(0, (threads_by_path[path] or {}))
    else
    end
    return schedule_check()
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = augroup_name, callback = _50_})
  vim.api.nvim_create_autocmd({"WinEnter", "TabEnter", "CursorMoved", "CursorMovedI"}, {group = augroup_name, callback = schedule_check})
  local function _52_(ev)
    if (pane_win == tonumber(ev.match)) then
      pane_win = nil
      return nil
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {group = augroup_name, callback = _52_})
  return vim.api.nvim_create_autocmd("User", {group = augroup_name, pattern = {"CodeboomerAnnotated", "CodeboomerSessionChanged", "CodeboomerImported"}, callback = M["reload-threads"]})
end
local function _54_()
  if enabled then
    return vim.notify("codeboomer: review pane already active", vim.log.levels.INFO)
  else
    enabled = true
    M["reload-threads"]()
    return check_now()
  end
end
M.open = _54_
local function _56_()
  enabled = false
  sticky = false
  if timer_id then
    vim.fn.timer_stop(timer_id)
    timer_id = nil
  else
  end
  return hide_pane()
end
M.close = _56_
local function _58_()
  enabled = true
  sticky = true
  M["reload-threads"]()
  return check_now()
end
M["open-sticky"] = _58_
local function _59_()
  if enabled then
    return M.close()
  else
    return M.open()
  end
end
M.toggle = _59_
local function _61_()
  return (pane_win and vim.api.nvim_win_is_valid(pane_win))
end
M["pane-valid"] = _61_
local function _62_()
  if not (pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    M["reload-threads"]()
    check_now()
  else
  end
  if (pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    return vim.api.nvim_set_current_win(pane_win)
  else
    return vim.notify("codeboomer: no review thread under the cursor", vim.log.levels.INFO)
  end
end
M.enter = _62_
attach_autocmds()
return M
