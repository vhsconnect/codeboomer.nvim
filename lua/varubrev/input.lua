-- [nfnl] fnl/varubrev/input.fnl
vim = vim
local M = {}
local function close_win(win)
  if vim.api.nvim_win_is_valid(win) then
    return vim.api.nvim_win_close(win, true)
  else
    return nil
  end
end
local function open(_2_)
  local on_submit = _2_["on-submit"]
  local alt_on_submit = _2_.on_submit
  local title = _2_.title
  local on_submit0 = (on_submit or alt_on_submit)
  local buf = vim.api.nvim_create_buf(false, true)
  local bo = vim.bo[buf]
  local width = math.floor((vim.o.columns * 0.6))
  local height = math.floor((vim.o.lines * 0.3))
  local win = vim.api.nvim_open_win(buf, true, {relative = "editor", row = math.floor(((vim.o.lines - height) / 2)), col = math.floor(((vim.o.columns - width) / 2)), width = width, height = height, style = "minimal", border = "rounded", title = (title or " Input "), title_pos = "center"})
  local submitted_3f = false
  bo.bufhidden = "wipe"
  local function finish()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    submitted_3f = true
    close_win(win)
    if on_submit0 then
      return on_submit0(lines)
    else
      return nil
    end
  end
  local function _4_()
    if not submitted_3f then
      return finish()
    else
      return nil
    end
  end
  vim.api.nvim_create_autocmd("WinClosed", {pattern = tostring(win), once = true, callback = _4_})
  vim.cmd.startinsert()
  return win
end
M.open = open
return M
