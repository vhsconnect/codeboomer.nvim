-- [nfnl] codeboomer/init.fnl
vim = vim
local config = require("codeboomer.config")
local input = require("codeboomer.input")
local directives = require("codeboomer.directives")
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
          return vim.notify(("codeboomer: one-off failed (exit " .. obj.code .. ")\n" .. (obj.stderr or "")), vim.log.levels.ERROR)
        end
      end
      return promise(_9_)
    end
    return vim.system(vim.list_extend(vim.list_slice(cmd), {prompt}), {text = true, timeout = 60000}, _8_)
  else
    return schedule_notify("codeboomer: prompting.one_off_command not set \226\128\148 call setup() first", vim.log.levels.ERROR)
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
  local handle = io.popen(("tmux load-buffer -b codeboomer-paste - && " .. "tmux paste-buffer -p -r -d -b codeboomer-paste -t " .. pane_id), "w")
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
    schedule_notify(string.format("codeboomer: pane %s (%s:%s.%s) selected", pane["pane-id"], pane["session-name"], pane["window-index"], pane["pane-index"]), vim.log.levels.INFO)
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
local function one_off_prompt(context, text)
  if context then
    return compose_message(context, text)
  else
    return ("regarding " .. vim.api.nvim_buf_get_name(0) .. "\n" .. text .. "\n")
  end
end
local function _25_()
  return choose_pane(parse_panes(shell(panes_command)))
end
M.SetPane = _25_
local function _26_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    local function _27_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        return send_keys_to_selected_pane(compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = " SendPrompt> ", ["on-submit"] = _27_})
  else
    local function _29_()
      local context = get_visual_lines(opts)
      local function _30_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          return send_keys_to_selected_pane(compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " SendPrompt> ", ["on-submit"] = _30_})
    end
    return choose_pane(parse_panes(shell(panes_command)), _29_)
  end
end
M.SendPrompt = _26_
local function _33_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    if context then
      return send_keys_to_selected_pane(context.lines)
    else
      return nil
    end
  else
    local function _35_()
      local context = get_visual_lines(opts)
      if context then
        return send_keys_to_selected_pane(context.lines)
      else
        return nil
      end
    end
    return choose_pane(parse_panes(shell(panes_command)), _35_)
  end
end
M.SendSelection = _33_
local function _38_(opts)
  local context = get_visual_lines(opts)
  local function _39_(lines)
    local text = concat_list(lines)
    if (text ~= "") then
      return run_one_off(one_off_prompt(context, text))
    else
      return nil
    end
  end
  return input.open({title = " AskOneOff (Enter to send)> ", ["submit-on-enter"] = true, ["on-submit"] = _39_})
end
M.AskOneOff = _38_
local function _41_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    local function _42_(lines)
      local text = concat_list(lines)
      if (text ~= "") then
        return table.insert(state["query-parts"], compose_message(context, text))
      else
        return nil
      end
    end
    return input.open({title = " Annotate> ", ["on-submit"] = _42_})
  else
    local function _44_()
      local context = get_visual_lines(opts)
      local function _45_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          return table.insert(state["query-parts"], compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " Annotate> ", ["on-submit"] = _45_})
    end
    return choose_pane(parse_panes(shell(panes_command)), _44_)
  end
end
M.Annotate = _41_
local function _48_()
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
    local function _50_(selected)
      local selected_label = selected[1]
      local directive_text = directives.get(selected_label)
      local annotations = concat_list_with_format(state["query-parts"], "==Section Start==", "====", "==Section End==")
      send_keys_to_selected_pane((annotations .. directive_text .. "\n"))
      return clear_annotations()
    end
    return fzf.fzf_exec(lines, {prompt = "Pick a Directive> ", actions = {default = _50_}})
  else
    local function _51_()
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
      local function _53_(selected)
        local selected_label = selected[1]
        local directive_text = directives.get(selected_label)
        local annotations = concat_list_with_format(state["query-parts"], "==Section Start==", "====", "==Section End==")
        send_keys_to_selected_pane((annotations .. directive_text .. "\n"))
        return clear_annotations()
      end
      return fzf.fzf_exec(lines, {prompt = "Pick a Directive> ", actions = {default = _53_}})
    end
    return choose_pane(parse_panes(shell(panes_command)), _51_)
  end
end
M.FlushWithDirective = _48_
return M
