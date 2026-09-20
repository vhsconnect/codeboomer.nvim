-- [nfnl] fnl/codeboomer/sidebar.fnl
vim = vim
local review = require("codeboomer.review")
local input = require("codeboomer.input")
local git = require("codeboomer.git")
local M = {}
local augroup_name = "codeboomer-review-pane"
local pane_buf_name = "codeboomer://review-comments"
local extmark_ns = vim.api.nvim_create_namespace("codeboomer-review-pane")
local flash_ns = vim.api.nvim_create_namespace("codeboomer-review-flash")
local flash_ms = 2000
local pane_width = 40
local sign_text = "\226\150\140"
local rest_ms = 100
local pane_win = nil
local threads_by_path = {}
local all_threads = {}
local timer_id = nil
local open_path_resolver = nil
M["set-open-path"] = function(f)
  open_path_resolver = f
  return nil
end
local function resolve_open_path(path)
  return ((open_path_resolver and open_path_resolver(path)) or ((git["repo-root"]() or "") .. "/" .. path))
end
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
    vim.api.nvim_buf_clear_namespace(bufnr, extmark_ns, 0, -1)
    local _2_
    do
      local t_1_ = vim.b
      if (nil ~= t_1_) then
        t_1_ = t_1_[bufnr]
      else
      end
      if (nil ~= t_1_) then
        t_1_ = t_1_.codeboomer_review_side
      else
      end
      _2_ = t_1_
    end
    if ("new" == _2_) then
      local line_count = vim.api.nvim_buf_line_count(bufnr)
      local taken = {}
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
  else
    return nil
  end
end
local function normal_buf(bufnr)
  local _9_
  do
    local t_8_ = vim.bo
    if (nil ~= t_8_) then
      t_8_ = t_8_[bufnr]
    else
    end
    if (nil ~= t_8_) then
      t_8_ = t_8_.buftype
    else
    end
    _9_ = t_8_
  end
  return ("" == (_9_ or ""))
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
local function thread_header(base, t)
  local status
  if (t.gh_outdated and ((t.gh_outdated or 0) > 0)) then
    status = ((t.status or "open") .. ", outdated")
  else
    status = (t.status or "open")
  end
  return string.format("#%d  %s:%s-%s  (%s)", (t.id or 0), base, (t.line_start or "?"), (t.line_end or "?"), status)
end
local function comment_label(c)
  local name
  local _17_
  do
    local t_16_ = review["comment-author"](c)
    if (nil ~= t_16_) then
      t_16_ = t_16_.name
    else
    end
    _17_ = t_16_
  end
  name = (_17_ or "unknown")
  return string.format("[%s] %s", (c.source or "user"), name)
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
    for j, c in ipairs(review["comments-for"](t.id)) do
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
  return {lines = lines, headers = headers, labels = labels}
end
local function render_pane(path, threads)
  local buf = vim.api.nvim_win_get_buf(pane_win)
  local bo = vim.bo[buf]
  local _let_21_ = render(path, threads)
  local lines = _let_21_.lines
  local headers = _let_21_.headers
  local labels = _let_21_.labels
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
  local function _24_()
    local t_23_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_23_) then
      t_23_ = t_23_[1]
    else
    end
    return t_23_
  end
  t = pane_thread_at(_24_())
  if not t then
    return vim.notify("codeboomer: no thread block under the pane cursor", vim.log.levels.WARN)
  else
    local function _26_(lines)
      if review["user-reply"]((t.id or 0), table.concat(lines, "\n")) then
        return refresh_pane()
      else
        return nil
      end
    end
    return input.open({title = string.format(" Reply to thread #%d> ", (t.id or 0)), ["on-submit"] = _26_})
  end
end
local function covering_at_source()
  if not (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win) and pane_win and vim.api.nvim_win_is_valid(pane_win)) then
    return nil
  else
    local buf = vim.api.nvim_win_get_buf(pane_source_win)
    local _30_
    do
      local t_29_ = vim.b
      if (nil ~= t_29_) then
        t_29_ = t_29_[buf]
      else
      end
      if (nil ~= t_29_) then
        t_29_ = t_29_.codeboomer_review_side
      else
      end
      _30_ = t_29_
    end
    if ("old" == _30_) then
      return {}
    else
      local row
      do
        local t_33_ = vim.api.nvim_win_get_cursor(pane_source_win)
        if (nil ~= t_33_) then
          t_33_ = t_33_[1]
        else
        end
        row = t_33_
      end
      return threads_at((pane_path or ""), (row or 0))
    end
  end
end
local function pane_resolve()
  local t
  local function _38_()
    local t_37_ = vim.api.nvim_win_get_cursor(pane_win)
    if (nil ~= t_37_) then
      t_37_ = t_37_[1]
    else
    end
    return t_37_
  end
  t = pane_thread_at(_38_())
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
      vim.keymap.set("n", "r", pane_reply, {buffer = buf, desc = "codeboomer: reply to this thread"})
      vim.keymap.set("n", "q", pane_resolve, {buffer = buf, desc = "codeboomer: resolve this thread"})
      local function _44_()
        return pane_jump(1)
      end
      vim.keymap.set("n", "n", _44_, {buffer = buf, desc = "codeboomer: jump to the next thread"})
      local function _45_()
        return pane_jump(-1)
      end
      vim.keymap.set("n", "N", _45_, {buffer = buf, desc = "codeboomer: jump to the previous thread"})
    end
    vim.cmd("wincmd p")
  else
  end
  return render_pane(path, threads)
end
local function flash_line(win, row)
  local buf = vim.api.nvim_win_get_buf(win)
  local id = vim.api.nvim_buf_set_extmark(buf, flash_ns, (row - 1), 0, {end_row = row, hl_group = "IncSearch", hl_eol = true})
  local function _47_()
    if vim.api.nvim_buf_is_valid(buf) then
      return pcall(vim.api.nvim_buf_del_extmark, buf, flash_ns, id)
    else
      return nil
    end
  end
  return vim.defer_fn(_47_, flash_ms)
end
local function _49_(dir)
  if not (pane_source_win and vim.api.nvim_win_is_valid(pane_source_win)) then
    return vim.notify("codeboomer: the pane has no code window to jump from", vim.log.levels.WARN)
  else
    local n = #all_threads
    if (0 == n) then
      return vim.notify("codeboomer: no threads to jump to", vim.log.levels.WARN)
    else
      local t
      local function _51_()
        local t_50_ = vim.api.nvim_win_get_cursor(pane_win)
        if (nil ~= t_50_) then
          t_50_ = t_50_[1]
        else
        end
        return t_50_
      end
      t = pane_thread_at(_51_())
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
      local or_54_ = idx
      if not or_54_ then
        if (dir > 0) then
          or_54_ = -1
        else
          or_54_ = 0
        end
      end
      target0 = ((or_54_ + dir) % n)
      local target = all_threads[(target0 + 1)]
      local cur_path = git["rel-path"](vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(pane_source_win)))
      local function _56_()
        if (cur_path ~= target.file_path) then
          vim.cmd({cmd = "edit", args = {resolve_open_path(target.file_path)}})
        else
        end
        vim.api.nvim_win_set_cursor(pane_source_win, {(target.line_start or 1), 0})
        return vim.cmd("normal! zz")
      end
      vim.api.nvim_win_call(pane_source_win, _56_)
      flash_line(pane_source_win, (target.line_start or 1))
      show_pane(target.file_path, {target})
      return vim.api.nvim_win_set_cursor(pane_win, {1, 0})
    end
  end
end
pane_jump = _49_
local function evaluate_at(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local side
  do
    local t_60_ = vim.b
    if (nil ~= t_60_) then
      t_60_ = t_60_[buf]
    else
    end
    if (nil ~= t_60_) then
      t_60_ = t_60_.codeboomer_review_side
    else
    end
    side = t_60_
  end
  if ((side ~= "old") and normal_buf(buf)) then
    local row
    do
      local t_63_ = vim.api.nvim_win_get_cursor(win)
      if (nil ~= t_63_) then
        t_63_ = t_63_[1]
      else
      end
      row = t_63_
    end
    local path = git["rel-path"](vim.api.nvim_buf_get_name(buf))
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
    local _69_
    do
      local t_68_ = vim.api.nvim_win_get_config(win)
      if (nil ~= t_68_) then
        t_68_ = t_68_.relative
      else
      end
      _69_ = t_68_
    end
    if ("" == (_69_ or "")) then
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
  local sid = review["current-session-id"]()
  threads_by_path = {}
  if sid then
    all_threads = review["threads-for-session"](sid)
  else
    all_threads = {}
  end
  for _, t in ipairs(all_threads) do
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
  vim.api.nvim_create_autocmd("BufEnter", {group = augroup_name, callback = schedule_check})
  vim.api.nvim_create_autocmd({"WinEnter", "TabEnter", "CursorMoved", "CursorMovedI"}, {group = augroup_name, callback = schedule_check})
  local function _75_(ev)
    if (pane_win == tonumber(ev.match)) then
      pane_win = nil
      return nil
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {group = augroup_name, callback = _75_})
  return vim.api.nvim_create_autocmd("User", {group = augroup_name, pattern = {"CodeboomerAnnotated", "CodeboomerSessionChanged", "CodeboomerImported"}, callback = M["reload-threads"]})
end
local function _77_(bufnr)
  local path = git["rel-path"](vim.api.nvim_buf_get_name(bufnr))
  return place_marks(bufnr, (threads_by_path[path] or {}))
end
M["mark-buffer"] = _77_
local function _78_()
  M["reload-threads"]()
  return check_now()
end
M.open = _78_
attach_autocmds()
return M
