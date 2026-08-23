-- [nfnl] varubrev/init.fnl
vim = vim
local config = require("varubrev.config")
local input = require("varubrev.input")
local directives = require("varubrev.directives")
local state = {pane = nil, ["query-parts"] = {}}
local M = {}
local function _1_(opts)
  return config.setup(opts)
end
M.setup = _1_
local promise = vim.schedule
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
local function one_off_result(stdout)
  local ok, parsed = pcall(vim.json.decode, stdout)
  if (ok and (type(parsed) == "table") and parsed.result) then
    return parsed.result
  else
    return stdout
  end
end
local function run_one_off(prompt)
  local cmd
  do
    local t_4_ = config
    if (nil ~= t_4_) then
      t_4_ = t_4_.config
    else
    end
    if (nil ~= t_4_) then
      t_4_ = t_4_.prompting
    else
    end
    if (nil ~= t_4_) then
      t_4_ = t_4_.one_off_command
    else
    end
    cmd = t_4_
  end
  if cmd then
    local function _8_(obj)
      local function _9_()
        if (obj.code == 0) then
          return vim.notify(one_off_result((obj.stdout or "")), vim.log.levels.INFO)
        else
          return vim.notify(("varubrev: one-off failed (exit " .. obj.code .. ")\n" .. (obj.stderr or "")), vim.log.levels.ERROR)
        end
      end
      return promise(_9_)
    end
    return vim.system(vim.list_extend(vim.list_slice(cmd), {prompt}), {text = true, timeout = 60000}, _8_)
  else
    return schedule_notify("varubrev: prompting.one_off_command not set \226\128\148 call setup() first", vim.log.levels.ERROR)
  end
end
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
local function paste_text(pane_id, text)
  local handle = io.popen(("tmux load-buffer -b varubrev-paste - && " .. "tmux paste-buffer -p -r -d -b varubrev-paste -t " .. pane_id), "w")
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
local function choose_pane(panes, _3fthen)
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
        local function _14_()
          if (p["pane-mode"] ~= "") then
            return ("[" .. p["pane-mode"] .. "]")
          else
            return ""
          end
        end
        display = string.format("%s:%s.%s  %-10s %-6s%s", p["session-name"], p["window-index"], p["pane-index"], p["pane-current-command"], p["pane-id"], _14_())
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
  local function _16_(selected)
    local pane = by_display[selected[1]]
    state.pane = pane
    schedule_notify(string.format("varubrev: pane %s (%s:%s.%s) selected", pane["pane-id"], pane["session-name"], pane["window-index"], pane["pane-index"]), vim.log.levels.INFO)
    if _3fthen then
      return _3fthen()
    else
      return nil
    end
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a Pane> ", actions = {default = _16_}})
end
local function clear_annotations()
  state["query-parts"] = {}
  return nil
end
M.RunOneOff = run_one_off
local function concat_list(lines)
  return table.concat(lines, "\n")
end
local function concat_list_with_format(lines, beginning, sep, _end)
  return (beginning .. "\n" .. table.concat(lines, (sep .. "\n")) .. "\n" .. _end .. "\n")
end
local function get_visual_lines(opts)
  local _19_
  do
    local t_18_ = opts
    if (nil ~= t_18_) then
      t_18_ = t_18_.range
    else
    end
    _19_ = t_18_
  end
  if (_19_ == 2) then
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
    return ("regarding " .. context.file .. " lines " .. context.line1 .. " to " .. context.line2 .. "\n" .. context.lines .. "\n" .. text .. "\n")
  else
    return text
  end
end
local function _24_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    local function _25_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        return table.insert(state["query-parts"], compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = " Annotate> ", ["on-submit"] = _25_})
  else
    local function _27_()
      local context = get_visual_lines(opts)
      local function _28_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          return table.insert(state["query-parts"], compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " Annotate> ", ["on-submit"] = _28_})
    end
    return choose_pane(parse_panes(shell(panes_command)), _27_)
  end
end
M.Annotate = _24_
local function _31_()
  if state.pane then
    local fzf = require("fzf-lua")
    local all_directives = directives.list()
    local lines
    do
      local tbl_26_ = {}
      local i_27_ = 0
      for _, d in ipairs(all_directives) do
        local val_28_ = d.label
        if (nil ~= val_28_) then
          i_27_ = (i_27_ + 1)
          tbl_26_[i_27_] = val_28_
        else
        end
      end
      lines = tbl_26_
    end
    local function _33_(selected)
      local selected_label = selected[1]
      local directive_text = directives.get(selected_label)
      local annotations = concat_list_with_format(state["query-parts"], "==Section Start==", "====", "==Section End==")
      send_keys_to_selected_pane((annotations .. directive_text .. "\n"))
      return clear_annotations()
    end
    return fzf.fzf_exec(lines, {prompt = "Pick a Directive> ", actions = {default = _33_}})
  else
    local function _34_()
      local fzf = require("fzf-lua")
      local all_directives = directives.list()
      local lines
      do
        local tbl_26_ = {}
        local i_27_ = 0
        for _, d in ipairs(all_directives) do
          local val_28_ = d.label
          if (nil ~= val_28_) then
            i_27_ = (i_27_ + 1)
            tbl_26_[i_27_] = val_28_
          else
          end
        end
        lines = tbl_26_
      end
      local function _36_(selected)
        local selected_label = selected[1]
        local directive_text = directives.get(selected_label)
        local annotations = concat_list_with_format(state["query-parts"], "==Section Start==", "====", "==Section End==")
        send_keys_to_selected_pane((annotations .. directive_text .. "\n"))
        return clear_annotations()
      end
      return fzf.fzf_exec(lines, {prompt = "Pick a Directive> ", actions = {default = _36_}})
    end
    return choose_pane(parse_panes(shell(panes_command)), _34_)
  end
end
M.SendWithDirective = _31_
local function _38_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    local function _39_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        return send_keys_to_selected_pane(compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = " Varubrev> ", ["on-submit"] = _39_})
  else
    local function _41_()
      local context = get_visual_lines(opts)
      local function _42_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          return send_keys_to_selected_pane(compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " Varubrev> ", ["on-submit"] = _42_})
    end
    return choose_pane(parse_panes(shell(panes_command)), _41_)
  end
end
M.SendKeys = _38_
local function _45_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    local function _46_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        return run_one_off(compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = " one-off (Enter to send)> ", ["submit-on-enter"] = true, ["on-submit"] = _46_})
  else
    local function _48_()
      local context = get_visual_lines(opts)
      local function _49_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          return run_one_off(compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " one-off (Enter to send)> ", ["submit-on-enter"] = true, ["on-submit"] = _49_})
    end
    return choose_pane(parse_panes(shell(panes_command)), _48_)
  end
end
M.SendKeysOO = _45_
local function _52_()
  return choose_pane(parse_panes(shell(panes_command)))
end
M.SetPane = _52_
return M
