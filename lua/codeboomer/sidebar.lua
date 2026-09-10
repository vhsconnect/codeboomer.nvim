-- [nfnl] codeboomer/sidebar.fnl
vim = vim
local review = require("codeboomer.review")
local M = {}
local augroup_name = "codeboomer-review-pane"
local pane_buf_name = "codeboomer://review-comments"
local extmark_ns = vim.api.nvim_create_namespace("codeboomer-review-pane")
local pane_width = 40
local sign_text = "\226\156\142"
local rest_ms = 100
local enabled = false
local pane_win = nil
local threads_by_path = {}
local timer_id = nil
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
      local hl = thread_hl(i)
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
local function mark_loaded_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local path = vim.api.nvim_buf_get_name(bufnr)
      local threads = threads_by_path[path]
      if threads then
        place_marks(bufnr, threads)
      else
      end
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
  return string.format("#%d  %s:%s-%s  (%s)", (t.id or 0), base, (t.line_start or "?"), (t.line_end or "?"), (t.status or "open"))
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
    table.insert(headers, {row = (#lines + 1), hl = thread_hl(i)})
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
  local _let_8_ = render(path, threads)
  local lines = _let_8_.lines
  local headers = _let_8_.headers
  vim.api.nvim_buf_clear_namespace(buf, extmark_ns, 0, -1)
  bo.modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  bo.modifiable = false
  for _, h in ipairs(headers) do
    vim.api.nvim_buf_set_extmark(buf, extmark_ns, (h.row - 1), 0, {line_hl_group = h.hl})
  end
  return nil
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
    end
    vim.cmd("wincmd p")
  else
  end
  return render_pane(path, threads)
end
local function check_now()
  local win = vim.api.nvim_get_current_win()
  local and_12_ = (win ~= pane_win)
  if and_12_ then
    local _14_
    do
      local t_13_ = vim.api.nvim_win_get_config(win)
      if (nil ~= t_13_) then
        t_13_ = t_13_.relative
      else
      end
      _14_ = t_13_
    end
    and_12_ = ("" == (_14_ or ""))
  end
  if and_12_ then
    local row
    do
      local t_16_ = vim.api.nvim_win_get_cursor(win)
      if (nil ~= t_16_) then
        t_16_ = t_16_[1]
      else
      end
      row = t_16_
    end
    local path = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    local threads = threads_at(path, (row or 0))
    if (enabled and (#threads > 0)) then
      return show_pane(path, threads)
    else
      return hide_pane()
    end
  else
    return nil
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
local function reload_threads()
  local ok, sid = pcall(review["active-session-id"])
  if ok then
    threads_by_path = {}
    local function _21_()
      if sid then
        return review["threads-for-session"](sid)
      else
        return {}
      end
    end
    for _, t in ipairs(_21_()) do
      local path = (t.file_path or "")
      threads_by_path[path] = vim.list_extend((threads_by_path[path] or {}), {t})
    end
    mark_loaded_buffers()
    return schedule_check()
  else
    local function _22_()
      return vim.notify(("codeboomer: " .. tostring(sid)), vim.log.levels.ERROR)
    end
    return vim.schedule(_22_)
  end
end
local function attach_autocmds()
  vim.api.nvim_create_augroup(augroup_name, {clear = true})
  vim.api.nvim_create_autocmd("VimEnter", {group = augroup_name, callback = reload_threads})
  local function _24_()
    do
      local path = vim.api.nvim_buf_get_name(0)
      local threads = threads_by_path[path]
      if threads then
        place_marks(0, threads)
      else
      end
    end
    return schedule_check()
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = augroup_name, callback = _24_})
  vim.api.nvim_create_autocmd({"WinEnter", "TabEnter", "CursorMoved", "CursorMovedI"}, {group = augroup_name, callback = schedule_check})
  local function _26_(ev)
    if (pane_win == tonumber(ev.match)) then
      pane_win = nil
      return nil
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {group = augroup_name, callback = _26_})
  return vim.api.nvim_create_autocmd("User", {group = augroup_name, pattern = "CodeboomerAnnotated", callback = reload_threads})
end
local function _28_()
  if enabled then
    return vim.notify("codeboomer: review pane already active", vim.log.levels.INFO)
  else
    enabled = true
    return check_now()
  end
end
M.open = _28_
local function _30_()
  enabled = false
  if timer_id then
    vim.fn.timer_stop(timer_id)
    timer_id = nil
  else
  end
  return hide_pane()
end
M.close = _30_
local function _32_()
  if enabled then
    return M.close()
  else
    return M.open()
  end
end
M.toggle = _32_
attach_autocmds()
if (1 == vim.v.vim_did_enter) then
  reload_threads()
else
end
return M
