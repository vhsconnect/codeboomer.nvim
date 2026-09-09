-- [nfnl] fnl/codeboomer/sidebar.fnl
vim = vim
local review = require("codeboomer.review")
local M = {}
local augroup_name = "codeboomer-review-pane"
local pane_buf_name = "codeboomer://review-comments"
local extmark_ns = vim.api.nvim_create_namespace("codeboomer-review-pane")
local pane_width = 40
local sign_text = "\226\156\142"
local state = {win = nil, buf = nil, ["code-win"] = nil, ["session-id"] = nil, threads = nil, ["threads-path"] = nil, ["signs-buf"] = nil, ["signcolumn-was"] = nil}
local function notify(msg, level)
  local function _1_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_1_)
end
local function win_valid_3f(win)
  return (win and vim.api.nvim_win_is_valid(win))
end
local function thread_hl(index)
  local groups = {"Title", "Special", "String", "Function"}
  return groups[(1 + ((index - 1) % #groups))]
end
local function place_signs(bufnr, threads)
  if (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
    if (state["signs-buf"] and vim.api.nvim_buf_is_valid(state["signs-buf"])) then
      vim.api.nvim_buf_clear_namespace(state["signs-buf"], extmark_ns, 0, -1)
    else
    end
    vim.api.nvim_buf_clear_namespace(bufnr, extmark_ns, 0, -1)
    for i, t in ipairs(threads) do
      local start = (t.line_start or 0)
      local finish = (t.line_end or start)
      local hl = thread_hl(i)
      for ln = start, finish do
        vim.api.nvim_buf_set_extmark(bufnr, extmark_ns, (ln - 1), 0, {sign_text = sign_text, sign_hl_group = hl, priority = (1000 - i)})
      end
    end
    state["signs-buf"] = bufnr
    return nil
  else
    return nil
  end
end
local function cached_threads(path, bufnr)
  if (state.threads and (state["threads-path"] == path)) then
    return state.threads
  else
    local threads
    if (state["session-id"] and (path ~= "")) then
      threads = review["threads-for"](state["session-id"], path)
    else
      threads = {}
    end
    state.threads = threads
    state["threads-path"] = path
    place_signs(bufnr, threads)
    return threads
  end
end
local function threads_at(path, bufnr, line)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, t in ipairs(cached_threads(path, bufnr)) do
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
local function thread_header(t)
  return string.format("#%d  %s:%s-%s  (%s)", (t.id or 0), (vim.fs.basename((state["threads-path"] or "")) or "?"), (t.line_start or "?"), (t.line_end or "?"), (t.status or "open"))
end
local function render(threads)
  local lines = {}
  local headers = {}
  for i, t in ipairs(threads) do
    if (i > 1) then
      table.insert(lines, string.rep("\226\148\128", pane_width))
    else
    end
    table.insert(headers, {row = (#lines + 1), hl = thread_hl(i)})
    table.insert(lines, thread_header(t))
    for _, c in ipairs(review["comments-for"](t.id)) do
      for _0, l in ipairs(vim.split((c.body or ""), "\n")) do
        table.insert(lines, l)
      end
    end
  end
  return {lines = lines, headers = headers}
end
local function set_pane_lines(lines)
  if (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    local bo = vim.bo[state.buf]
    vim.api.nvim_buf_clear_namespace(state.buf, extmark_ns, 0, -1)
    bo.modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    bo.modifiable = false
    return nil
  else
    return nil
  end
end
local function update()
  if (win_valid_3f(state["code-win"]) and state.buf) then
    local code_buf = vim.api.nvim_win_get_buf(state["code-win"])
    local path = vim.api.nvim_buf_get_name(code_buf)
    local cursor_row
    do
      local t_10_ = vim.api.nvim_win_get_cursor(state["code-win"])
      if (nil ~= t_10_) then
        t_10_ = t_10_[1]
      else
      end
      cursor_row = t_10_
    end
    local _let_12_ = render(threads_at(path, code_buf, (cursor_row or 0)))
    local lines = _let_12_.lines
    local headers = _let_12_.headers
    set_pane_lines(lines)
    for _, h in ipairs(headers) do
      vim.api.nvim_buf_set_extmark(state.buf, extmark_ns, (h.row - 1), 0, {line_hl_group = h.hl})
    end
    return nil
  else
    return nil
  end
end
local function teardown()
  pcall(vim.api.nvim_del_augroup_by_name, augroup_name)
  if (state["signs-buf"] and vim.api.nvim_buf_is_valid(state["signs-buf"])) then
    vim.api.nvim_buf_clear_namespace(state["signs-buf"], extmark_ns, 0, -1)
  else
  end
  if (win_valid_3f(state["code-win"]) and state["signcolumn-was"]) then
    local wo = vim.wo[state["code-win"]]
    local function _15_()
      wo.signcolumn = state["signcolumn-was"]
      return nil
    end
    pcall(_15_)
  else
  end
  if win_valid_3f(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  else
  end
  state.win = nil
  state.buf = nil
  state["code-win"] = nil
  state["session-id"] = nil
  state.threads = nil
  state["threads-path"] = nil
  state["signs-buf"] = nil
  state["signcolumn-was"] = nil
  return nil
end
local function attach_autocmds()
  vim.api.nvim_create_augroup(augroup_name, {clear = true})
  local function _18_()
    if (win_valid_3f(state["code-win"]) and (vim.api.nvim_get_current_win() == state["code-win"])) then
      return update()
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI", "BufEnter"}, {group = augroup_name, callback = _18_})
  vim.api.nvim_create_autocmd("WinClosed", {group = augroup_name, pattern = tostring(state["code-win"]), once = true, callback = teardown})
  vim.api.nvim_create_autocmd("WinClosed", {group = augroup_name, pattern = tostring(state.win), once = true, callback = teardown})
  local function _20_()
    state.threads = nil
    state["threads-path"] = nil
    do
      local ok, session_id = pcall(review["active-session-id"])
      if ok then
        state["session-id"] = session_id
      else
        state["session-id"] = nil
      end
    end
    return update()
  end
  return vim.api.nvim_create_autocmd("User", {group = augroup_name, pattern = "CodeboomerAnnotated", callback = _20_})
end
local function _22_()
  if win_valid_3f(state.win) then
    return notify("codeboomer: comments pane already open", vim.log.levels.INFO)
  else
    local ok, session_id = pcall(review["active-session-id"])
    if not ok then
      return notify(("codeboomer: " .. tostring(session_id)), vim.log.levels.ERROR)
    else
      state["session-id"] = session_id
      state["code-win"] = vim.api.nvim_get_current_win()
      state.threads = nil
      state["threads-path"] = nil
      do
        local wo = vim.wo[state["code-win"]]
        state["signcolumn-was"] = wo.signcolumn
        wo.signcolumn = "auto:2"
      end
      vim.cmd(string.format("botright %dvnew", pane_width))
      state.win = vim.api.nvim_get_current_win()
      state.buf = vim.api.nvim_get_current_buf()
      do
        local bo = vim.bo[state.buf]
        local wo = vim.wo[state.win]
        bo.buftype = "nofile"
        bo.swapfile = false
        bo.bufhidden = "wipe"
        bo.modifiable = false
        pcall(vim.api.nvim_buf_set_name, state.buf, pane_buf_name)
        wo.wrap = true
        wo.linebreak = true
        wo.number = false
        wo.relativenumber = false
        wo.signcolumn = "no"
        wo.winfixwidth = true
      end
      vim.cmd("wincmd p")
      attach_autocmds()
      update()
      if (state["session-id"] == nil) then
        return notify("codeboomer: no review session yet \226\128\148 Annotate creates one", vim.log.levels.INFO)
      else
        return nil
      end
    end
  end
end
M.open = _22_
M.close = teardown
local function _26_()
  if win_valid_3f(state.win) then
    return teardown()
  else
    return M.open()
  end
end
M.toggle = _26_
return M
