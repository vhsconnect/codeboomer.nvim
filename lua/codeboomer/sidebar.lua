-- [nfnl] codeboomer/sidebar.fnl
vim = vim
local review = require("codeboomer.review")
local M = {}
local augroup_name = "codeboomer-review-pane"
local pane_buf_prefix = "codeboomer://review-comments/"
local extmark_ns = vim.api.nvim_create_namespace("codeboomer-review-pane")
local pane_width = 40
local sign_text = "\226\156\142"
local enabled = false
local sidebars = {}
local active_tab = nil
local function notify(msg, level)
  local function _1_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_1_)
end
local function win_valid_3f(win)
  return (win and vim.api.nvim_win_is_valid(win))
end
local function owner_of(win)
  local owner = nil
  for _, sb in pairs(sidebars) do
    if (sb.win == win) then
      owner = sb
    else
    end
  end
  return owner
end
local function floating_3f(win)
  local _4_
  do
    local t_3_ = vim.api.nvim_win_get_config(win)
    if (nil ~= t_3_) then
      t_3_ = t_3_.relative
    else
    end
    _4_ = t_3_
  end
  return ("" ~= (_4_ or ""))
end
local function thread_hl(index)
  local groups = {"Title", "Special", "String", "Function"}
  return groups[(1 + ((index - 1) % #groups))]
end
local function release_signs(sb)
  if (sb["signs-buf"] and vim.api.nvim_buf_is_valid(sb["signs-buf"])) then
    vim.api.nvim_buf_clear_namespace(sb["signs-buf"], extmark_ns, 0, -1)
  else
  end
  sb["signs-buf"] = nil
  return nil
end
local function place_signs(sb, bufnr, threads)
  if (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    release_signs(sb)
    vim.api.nvim_buf_clear_namespace(bufnr, extmark_ns, 0, -1)
    for i, t in ipairs(threads) do
      local start = (t.line_start or 0)
      local finish = (t.line_end or start)
      local hl = thread_hl(i)
      for ln = start, finish do
        vim.api.nvim_buf_set_extmark(bufnr, extmark_ns, (ln - 1), 0, {sign_text = sign_text, sign_hl_group = hl, priority = (1000 - i)})
      end
    end
    sb["signs-buf"] = bufnr
    return nil
  else
    return nil
  end
end
local function cached_threads(sb, path, bufnr)
  if (sb.threads and (sb["threads-path"] == path)) then
    return sb.threads
  else
    local threads
    if (sb["session-id"] and (path ~= "")) then
      threads = review["threads-for"](sb["session-id"], path)
    else
      threads = {}
    end
    sb.threads = threads
    sb["threads-path"] = path
    place_signs(sb, bufnr, threads)
    return threads
  end
end
local function threads_at(sb, path, bufnr, line)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, t in ipairs(cached_threads(sb, path, bufnr)) do
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
local function render(sb, threads)
  local lines = {}
  local headers = {}
  local base = (vim.fs.basename((sb["threads-path"] or "")) or "?")
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
local function set_pane_lines(sb, lines)
  if (sb.buf and vim.api.nvim_buf_is_valid(sb.buf)) then
    local bo = vim.bo[sb.buf]
    vim.api.nvim_buf_clear_namespace(sb.buf, extmark_ns, 0, -1)
    bo.modifiable = true
    vim.api.nvim_buf_set_lines(sb.buf, 0, -1, false, lines)
    bo.modifiable = false
    return nil
  else
    return nil
  end
end
local function update(sb, win)
  if (win_valid_3f(win) and sb.buf and vim.api.nvim_buf_is_valid(sb.buf)) then
    local code_buf = vim.api.nvim_win_get_buf(win)
    local path = vim.api.nvim_buf_get_name(code_buf)
    local cursor_row
    do
      local t_14_ = vim.api.nvim_win_get_cursor(win)
      if (nil ~= t_14_) then
        t_14_ = t_14_[1]
      else
      end
      cursor_row = t_14_
    end
    local threads = threads_at(sb, path, code_buf, (cursor_row or 0))
    local _let_16_ = render(sb, threads)
    local lines = _let_16_.lines
    local headers = _let_16_.headers
    set_pane_lines(sb, lines)
    for _, h in ipairs(headers) do
      vim.api.nvim_buf_set_extmark(sb.buf, extmark_ns, (h.row - 1), 0, {line_hl_group = h.hl})
    end
    return nil
  else
    return nil
  end
end
local function drive(sb, win)
  do
    local wo = vim.wo[win]
    if not sb["touched-wins"][win] then
      sb["touched-wins"][win] = wo.signcolumn
    else
    end
    wo.signcolumn = "auto:2"
  end
  return update(sb, win)
end
local function tab_active_win(tab)
  if vim.api.nvim_tabpage_is_valid(tab) then
    local win = vim.api.nvim_tabpage_get_win(tab)
    if not owner_of(win) then
      return win
    else
      return nil
    end
  else
    return nil
  end
end
local function resolve_session()
  local ok, session_id = pcall(review["active-session-id"])
  if ok then
    return session_id
  else
    notify(("codeboomer: " .. tostring(session_id)), vim.log.levels.ERROR)
    return nil
  end
end
local function spawn(tab)
  local sb = {tab = tab, win = nil, buf = nil, ["session-id"] = nil, threads = nil, ["threads-path"] = nil, ["signs-buf"] = nil, ["touched-wins"] = {}}
  sidebars[tab] = sb
  return sb
end
local function spawn_pane(sb)
  sb["session-id"] = resolve_session()
  vim.cmd(string.format("botright %dvnew", pane_width))
  sb.win = vim.api.nvim_get_current_win()
  sb.buf = vim.api.nvim_get_current_buf()
  do
    local bo = vim.bo[sb.buf]
    local wo = vim.wo[sb.win]
    bo.buftype = "nofile"
    bo.swapfile = false
    bo.bufhidden = "wipe"
    bo.modifiable = false
    pcall(vim.api.nvim_buf_set_name, sb.buf, (pane_buf_prefix .. sb.tab))
    wo.wrap = true
    wo.linebreak = true
    wo.number = false
    wo.relativenumber = false
    wo.signcolumn = "no"
    wo.winfixwidth = true
  end
  vim.cmd("wincmd p")
  return drive(sb, vim.api.nvim_get_current_win())
end
local function teardown(sb)
  sidebars[sb.tab] = nil
  release_signs(sb)
  for win, was in pairs((sb["touched-wins"] or {})) do
    if win_valid_3f(win) then
      local wo = vim.wo[win]
      local function _22_()
        wo.signcolumn = was
        return nil
      end
      pcall(_22_)
    else
    end
  end
  if win_valid_3f(sb.win) then
    return pcall(vim.api.nvim_win_close, sb.win, true)
  else
    return nil
  end
end
local function dispatch()
  local win = vim.api.nvim_get_current_win()
  if (not owner_of(win) and not floating_3f(win)) then
    local sb = sidebars[vim.api.nvim_get_current_tabpage()]
    if (sb and sb.win) then
      return drive(sb, win)
    else
      return nil
    end
  else
    return nil
  end
end
local function ensure_current_tab()
  if enabled then
    local tab = vim.api.nvim_get_current_tabpage()
    if (active_tab and (active_tab ~= tab)) then
      local prev = sidebars[active_tab]
      if prev then
        release_signs(prev)
      else
      end
    else
    end
    active_tab = tab
    local sb = sidebars[tab]
    if (sb and win_valid_3f(sb.win)) then
      sb.threads = nil
      sb["threads-path"] = nil
      local win = vim.api.nvim_get_current_win()
      if not owner_of(win) then
        return drive(sb, win)
      else
        return nil
      end
    else
      if sb then
        teardown(sb)
      else
      end
      return spawn_pane(spawn(tab))
    end
  else
    return nil
  end
end
local function refresh_all()
  local session_id = resolve_session()
  for _, sb in pairs(vim.tbl_values(sidebars)) do
    sb["session-id"] = session_id
    sb.threads = nil
    sb["threads-path"] = nil
    local win = tab_active_win(sb.tab)
    if win then
      update(sb, win)
    else
    end
  end
  return nil
end
local function attach_autocmds()
  vim.api.nvim_create_augroup(augroup_name, {clear = true})
  local function _34_()
    return dispatch()
  end
  vim.api.nvim_create_autocmd({"WinEnter", "BufEnter", "CursorMoved", "CursorMovedI"}, {group = augroup_name, callback = _34_})
  local function _35_()
    return ensure_current_tab()
  end
  vim.api.nvim_create_autocmd("TabEnter", {group = augroup_name, callback = _35_})
  local function _36_(ev)
    local win = tonumber(ev.match)
    local sb = (win and owner_of(win))
    if sb then
      return teardown(sb)
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {group = augroup_name, callback = _36_})
  local function _38_()
    return refresh_all()
  end
  return vim.api.nvim_create_autocmd("User", {group = augroup_name, pattern = "CodeboomerAnnotated", callback = _38_})
end
local function _39_()
  if enabled then
    return notify("codeboomer: review panes already active", vim.log.levels.INFO)
  else
    local tab = vim.api.nvim_get_current_tabpage()
    attach_autocmds()
    enabled = true
    active_tab = tab
    spawn_pane(spawn(tab))
    if (sidebars[tab]["session-id"] == nil) then
      return notify("codeboomer: no review session yet \226\128\148 Annotate creates one", vim.log.levels.INFO)
    else
      return nil
    end
  end
end
M.open = _39_
local function _42_()
  for _, sb in pairs(vim.tbl_values(sidebars)) do
    teardown(sb)
  end
  enabled = false
  active_tab = nil
  return pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
end
M.close = _42_
local function _43_()
  if enabled then
    return M.close()
  else
    return M.open()
  end
end
M.toggle = _43_
return M
