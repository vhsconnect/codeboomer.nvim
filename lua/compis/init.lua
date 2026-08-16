-- [nfnl] compis/init.fnl
vim = vim
local core = require("nfnl.core")
local config = require("compis.config")
local input = require("compis.input")
local provider = require("compis.provider")
local state = {pane = nil}
local M = {}
local function _1_(opts)
  return config.setup(opts)
end
M.setup = _1_
local promise = vim.schedule
local sessions_command = "tmux list-session -F '#{session_name}|#{session_windows}|#{session_attached}'"
local function schedule_notify(msg, level)
  local function _2_()
    return vim.notify(msg, level)
  end
  return promise(_2_)
end
local function shell(command)
  local handle = io.popen(command)
  local output = handle:read("*a")
  handle:close()
  return output
end
local panes_command = "tmux list-panes -a -F '#{session_name}|#{session_id}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_mode}|#{pane_active}|#{window_active}'"
local function parse_panes(x)
  local pattern = "([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)"
  local result = string.gmatch(x, pattern)
  local tbl_26_ = {}
  local i_27_ = 0
  for session_name, session_id, window_index, pane_index, pane_id, pane_current_command, pane_mode, pane_active, window_active in result do
    local val_28_ = {["session-name"] = session_name, ["session-id"] = session_id, ["window-index"] = window_index, ["pane-index"] = pane_index, ["pane-id"] = pane_id, ["pane-current-command"] = pane_current_command, ["pane-mode"] = pane_mode, ["pane-active"] = pane_active, ["window-active"] = window_active}
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function parse_sessions(x)
  local tbl_26_ = {}
  local i_27_ = 0
  for name, windows, attached in string.gmatch(x, "([^|]*)|([^|]*)|([^|]*)") do
    local val_28_ = {name = name, windows = windows, session = attached}
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function paste_text(pane_id, text)
  local handle = io.popen(("tmux load-buffer -b compis-paste - && " .. "tmux paste-buffer -p -r -d -b compis-paste -t " .. pane_id), "w")
  handle:write(text)
  return handle:close()
end
local function press_key_command(pane_id, key)
  return string.format("tmux send-keys -t %s %s", pane_id, key)
end
local function cancel_mode_command(pane_id)
  return string.format("tmux send-keys -t %s -X cancel", pane_id)
end
local function send_keys_to_selected_pane(text)
  local pane_id = state.pane["pane-id"]
  if ("" ~= state.pane["pane-mode"]) then
    shell(cancel_mode_command(pane_id))
  else
  end
  paste_text(pane_id, text)
  return shell(press_key_command(pane_id, "Enter"))
end
local function choose_pane(panes)
  local fzf = require("fzf-lua")
  local by_display = {}
  local lines
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, p in ipairs(panes) do
      local val_28_
      do
        local display
        local function _6_()
          if (p["pane-mode"] ~= "") then
            return ("[" .. p["pane-mode"] .. "]")
          else
            return ""
          end
        end
        display = string.format("%s:%s.%s  %-10s %-6s%s", p["session-name"], p["window-index"], p["pane-index"], p["pane-current-command"], p["pane-id"], _6_())
        by_display[display] = p
        val_28_ = display
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    lines = tbl_26_
  end
  local function _8_(selected)
    local pane = by_display[selected[1]]
    state.pane = pane
    return schedule_notify(string.format("compis: pane %s (%s:%s.%s) selected", pane["pane-id"], pane["session-name"], pane["window-index"], pane["pane-index"]), vim.log.levels.INFO)
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a Pane> ", actions = {default = _8_}})
end
local function _9_()
  return parse_sessions(shell(sessions_command))
end
M.ParseSessions = _9_
local function _10_()
  return parse_panes(shell(panes_command))
end
M.ParsePanes = _10_
local function concat_list(lines)
  return table.concat(lines, "\n")
end
local function get_visual_lines(opts)
  local _12_
  do
    local t_11_ = opts
    if (nil ~= t_11_) then
      t_11_ = t_11_.range
    else
    end
    _12_ = t_11_
  end
  if (_12_ == 2) then
    local path = vim.api.nvim_buf_get_name(0)
    local ok, region_lines = pcall(vim.fn.getregion, vim.fn.getpos("'<"), vim.fn.getpos("'>"), {type = vim.fn.visualmode()})
    local lines
    if ok then
      lines = concat_list(region_lines)
    else
      lines = concat_list(vim.api.nvim_buf_get_lines(0, (opts.line1 - 1), opts.line2, false))
    end
    return {lines = lines, line1 = opts.line1, line2 = opts.line2, file = path}
  else
    return nil
  end
end
local function compose_message(context, text)
  if context then
    return ("regarding " .. context.file .. " lines " .. context.line1 .. " to " .. context.line2 .. "\n" .. context.lines .. "\n" .. text)
  else
    return text
  end
end
local function _17_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    local function _18_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        return send_keys_to_selected_pane(compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = " Compis> ", ["on-submit"] = _18_})
  else
    return schedule_notify("compis: no pane selected \226\128\148 run Compis SetPane first", vim.log.levels.WARN)
  end
end
M.SendKeys = _17_
local function _21_()
  return choose_pane(parse_panes(shell(panes_command)))
end
M.SetPane = _21_
return M
