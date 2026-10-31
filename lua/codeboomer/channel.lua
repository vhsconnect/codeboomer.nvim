-- [nfnl] fnl/codeboomer/channel.fnl
vim = vim
local M = {}
local id_prefix = "n"
local preview_lines = 40
local spawned = {}
local function pane_id(buf)
  return (id_prefix .. buf)
end
local function pane_buf(pane)
  return (pane.buf or tonumber(string.sub((pane["pane-id"] or ""), 2)))
end
local function term_bufs()
  local tbl_26_ = {}
  local i_27_ = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local val_28_
    local _2_
    do
      local t_1_ = vim.b
      if (nil ~= t_1_) then
        t_1_ = t_1_[buf]
      else
      end
      if (nil ~= t_1_) then
        t_1_ = t_1_.terminal_job_id
      else
      end
      _2_ = t_1_
    end
    if _2_ then
      val_28_ = buf
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
local function parse_name(name)
  local base, cmd = string.match(name, "^term://(.*)//%d+:(.*)$")
  if base then
    return base, cmd
  else
    return name, nil
  end
end
M["list-panes"] = function()
  local tbl_26_ = {}
  local i_27_ = 0
  for _, buf in ipairs(term_bufs()) do
    local val_28_
    do
      local name = vim.api.nvim_buf_get_name(buf)
      local base, cmd = parse_name(name)
      local own = spawned[buf]
      local _9_
      do
        local t_8_ = own
        if (nil ~= t_8_) then
          t_8_ = t_8_.argv0
        else
        end
        _9_ = t_8_
      end
      local _11_
      if (buf == vim.api.nvim_get_current_buf()) then
        _11_ = "1"
      else
        _11_ = "0"
      end
      local _14_
      do
        local t_13_ = own
        if (nil ~= t_13_) then
          t_13_ = t_13_.path
        else
        end
        _14_ = t_13_
      end
      local _17_
      do
        local t_16_ = vim.b
        if (nil ~= t_16_) then
          t_16_ = t_16_[buf]
        else
        end
        if (nil ~= t_16_) then
          t_16_ = t_16_.terminal_job_id
        else
        end
        _17_ = t_16_
      end
      val_28_ = {driver = "channel", ["session-name"] = "nvim", ["session-id"] = "nvim", ["window-index"] = "0", ["pane-index"] = tostring(buf), ["pane-id"] = pane_id(buf), ["pane-current-command"] = (_9_ or string.match((cmd or ""), "(%S+)") or (name or "term")), ["pane-mode"] = "", ["pane-active"] = _11_, ["window-active"] = "0", ["pane-current-path"] = (_14_ or (base or vim.fn.getcwd())), buf = buf, chan = _17_}
    end
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function last_line(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local out = ""
  for i = #lines, 1, -1 do
    if (out ~= "") then break end
    if (out == "") then
      out = vim.trim(lines[i])
    else
    end
  end
  return out
end
M["last-lines"] = function()
  local result = {}
  for _, p in ipairs(M["list-panes"]()) do
    result[p["pane-id"]] = last_line(p.buf)
  end
  return result
end
M.send = function(pane, text)
  local buf = pane_buf(pane)
  local chan
  if (buf and vim.api.nvim_buf_is_valid(buf)) then
    local t_22_ = vim.b
    if (nil ~= t_22_) then
      t_22_ = t_22_[buf]
    else
    end
    if (nil ~= t_22_) then
      t_22_ = t_22_.terminal_job_id
    else
    end
    chan = t_22_
  else
    chan = nil
  end
  if chan then
    return vim.fn.chansend(chan, ("\27[200~" .. text .. "\27[201~\r"))
  else
    return nil, "the terminal behind that pane is gone"
  end
end
M.spawn = function(cwd, name, argv)
  local back = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.cmd("botright vsplit")
  local split = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(split, buf)
  local ok, chan = pcall(vim.fn.termopen, argv, {cwd = cwd})
  if (ok and ((chan or -1) > 0)) then
    if not pcall(vim.api.nvim_buf_set_name, buf, name) then
      pcall(vim.api.nvim_buf_set_name, buf, (name .. "-" .. buf))
    else
    end
    spawned[buf] = {label = name, argv0 = argv[1], path = cwd}
    vim.api.nvim_set_current_win(back)
    return {driver = "channel", ["session-name"] = "nvim", ["session-id"] = "nvim", ["window-index"] = "0", ["pane-index"] = tostring(buf), ["pane-id"] = pane_id(buf), ["pane-current-command"] = argv[1], ["pane-mode"] = "", ["pane-active"] = "0", ["window-active"] = "0", ["pane-current-path"] = cwd, buf = buf, chan = chan}
  else
    vim.api.nvim_set_current_win(back)
    vim.api.nvim_win_close(split, true)
    vim.api.nvim_buf_delete(buf, {force = true})
    return nil, ("failed to start " .. tostring(argv[1]))
  end
end
local function windows_for(buf)
  local wins = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    for _0, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if (buf == vim.api.nvim_win_get_buf(w)) then
        table.insert(wins, w)
      else
      end
    end
  end
  return wins
end
M.toggle = function(pane)
  local buf = pane_buf(pane)
  local live
  local and_30_ = buf and vim.api.nvim_buf_is_valid(buf)
  if and_30_ then
    local t_31_ = vim.b
    if (nil ~= t_31_) then
      t_31_ = t_31_[buf]
    else
    end
    if (nil ~= t_31_) then
      t_31_ = t_31_.terminal_job_id
    else
    end
    and_30_ = t_31_
  end
  live = and_30_
  if not live then
    return nil, "the terminal behind that pane is gone"
  else
    local wins = windows_for(buf)
    if (0 ~= #wins) then
      for _, w in ipairs(wins) do
        pcall(vim.api.nvim_win_close, w, false)
      end
      return "hidden"
    else
      vim.cmd("botright vsplit")
      vim.api.nvim_win_set_buf(0, buf)
      return "shown"
    end
  end
end
M.preview = function(id)
  local buf = tonumber(string.match((id or ""), ("^" .. id_prefix .. "(%d+)$")))
  local live
  local and_36_ = buf and vim.api.nvim_buf_is_valid(buf)
  if and_36_ then
    local t_37_ = vim.b
    if (nil ~= t_37_) then
      t_37_ = t_37_[buf]
    else
    end
    if (nil ~= t_37_) then
      t_37_ = t_37_.terminal_job_id
    else
    end
    and_36_ = t_37_
  end
  live = and_36_
  if live then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local from = math.max(1, (1 + (#lines - preview_lines)))
    return table.concat(vim.list_slice(lines, from), "\n")
  else
    return "(terminal buffer gone)"
  end
end
M["preview-command"] = ("p={1}; case \"$p\" in " .. id_prefix .. "*) nvim --server \"$NVIM\" --remote-expr " .. "\"v:lua.require('codeboomer.channel').preview('$p')\" 2>/dev/null " .. "|| echo '(terminal buffer gone)' ;; " .. "*) tmux capture-pane -p -t \"$p\" -S -" .. preview_lines .. " ;; esac")
return M
