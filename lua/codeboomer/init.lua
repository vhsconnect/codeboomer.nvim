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
local panes_command = "tmux list-panes -a -F '#{session_name}|#{session_id}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_mode}|#{pane_active}|#{window_active}|#{pane_current_path}'"
local last_lines_command = "tmux list-panes -a -F '#{pane_id}' | while read -r p; do printf '%s\\t' \"$p\"; tmux capture-pane -p -t \"$p\" -S -5 -E -1 2>/dev/null | sed -e '/^[[:space:]]*$/d' | tail -n 1; echo; done"
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
  local pattern = "([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)|([^|\n]*)"
  local result = string.gmatch(x, pattern)
  local tbl_26_ = {}
  local i_27_ = 0
  for session_name, session_id, window_index, pane_index, pane_id, pane_current_command, pane_mode, pane_active, window_active, pane_current_path in result do
    local val_28_ = {["session-name"] = session_name, ["session-id"] = session_id, ["window-index"] = window_index, ["pane-index"] = pane_index, ["pane-id"] = pane_id, ["pane-current-command"] = pane_current_command, ["pane-mode"] = pane_mode, ["pane-active"] = pane_active, ["window-active"] = window_active, ["pane-current-path"] = pane_current_path}
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function parse_last_lines(x)
  local result = {}
  for line in string.gmatch(x, "[^\n]+") do
    local sep = string.find(line, "\t", 1, true)
    if sep then
      result[string.sub(line, 1, (sep - 1))] = vim.trim(string.sub(line, (sep + 1)))
    else
    end
  end
  return result
end
local function shorten_path(path)
  local home = os.getenv("HOME")
  if (home and (1 == string.find(path, home, 1, true))) then
    return ("~" .. string.sub(path, (1 + #home)))
  else
    return path
  end
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
local last_line_max_length = 80
local function pane_display(p, last_line)
  local location = string.format("%s:%s.%s", p["session-name"], p["window-index"], p["pane-index"])
  local short_line
  if (#last_line > last_line_max_length) then
    short_line = (string.sub(last_line, 1, last_line_max_length) .. "\226\128\166")
  else
    short_line = last_line
  end
  local mode
  if (p["pane-mode"] ~= "") then
    mode = ("[" .. p["pane-mode"] .. "] ")
  else
    mode = ""
  end
  return string.format("%-6s %-11s %-18s %-30s %s%s", p["pane-id"], p["pane-current-command"], location, shorten_path(p["pane-current-path"]), mode, short_line)
end
local pane_preview_command = "tmux capture-pane -p -t {1} -S -40"
local function choose_pane(panes, _3fthen)
  local fzf = require("fzf-lua")
  local last_lines = parse_last_lines(shell(last_lines_command))
  local by_display = {}
  local lines
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, p in ipairs(panes) do
      local val_28_
      do
        local display = pane_display(p, last_lines[p["pane-id"]])
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
  local function _19_(selected)
    local pane = by_display[selected[1]]
    state.pane = pane
    schedule_notify(string.format("codeboomer: pane %s (%s:%s.%s) selected", pane["pane-id"], pane["session-name"], pane["window-index"], pane["pane-index"]), vim.log.levels.INFO)
    if _3fthen then
      return _3fthen()
    else
      return nil
    end
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a Pane> ", preview = pane_preview_command, fzf_opts = {["--with-nth"] = "2.."}, winopts = {preview = {layout = "vertical", vertical = "down:45%:follow", wrap = false}}, actions = {default = _19_}})
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
  local _22_
  do
    local t_21_ = opts
    if (nil ~= t_21_) then
      t_21_ = t_21_.range
    else
    end
    _22_ = t_21_
  end
  if (_22_ == 2) then
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
local function _28_()
  return choose_pane(parse_panes(shell(panes_command)))
end
M.SetPane = _28_
local function _29_(opts)
  if state.pane then
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
  else
    local function _32_()
      local context = get_visual_lines(opts)
      local function _33_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          return send_keys_to_selected_pane(compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " SendPrompt> ", ["on-submit"] = _33_})
    end
    return choose_pane(parse_panes(shell(panes_command)), _32_)
  end
end
M.SendPrompt = _29_
local function _36_(opts)
  if state.pane then
    local context = get_visual_lines(opts)
    if context then
      return send_keys_to_selected_pane(context.lines)
    else
      return nil
    end
  else
    local function _38_()
      local context = get_visual_lines(opts)
      if context then
        return send_keys_to_selected_pane(context.lines)
      else
        return nil
      end
    end
    return choose_pane(parse_panes(shell(panes_command)), _38_)
  end
end
M.SendSelection = _36_
local function _41_(opts)
  local context = get_visual_lines(opts)
  local function _42_(lines)
    local text = concat_list(lines)
    if (text ~= "") then
      return run_one_off(one_off_prompt(context, text))
    else
      return nil
    end
  end
  return input.open({title = " AskOneOff (Enter to send)> ", ["submit-on-enter"] = true, ["on-submit"] = _42_})
end
M.AskOneOff = _41_
local function _44_(opts)
  if state.pane then
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
  else
    local function _47_()
      local context = get_visual_lines(opts)
      local function _48_(lines)
        local text = concat_list(lines)
        if (text ~= "") then
          return table.insert(state["query-parts"], compose_message(context, text))
        else
          return nil
        end
      end
      return input.open({title = " Annotate> ", ["on-submit"] = _48_})
    end
    return choose_pane(parse_panes(shell(panes_command)), _47_)
  end
end
M.Annotate = _44_
local function _51_()
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
    local function _53_(selected)
      local selected_label = selected[1]
      local directive_text = directives.get(selected_label)
      local annotations = concat_list_with_format(state["query-parts"], "==Section Start==", "====", "==Section End==")
      send_keys_to_selected_pane((annotations .. directive_text .. "\n"))
      return clear_annotations()
    end
    return fzf.fzf_exec(lines, {prompt = "Pick a Directive> ", actions = {default = _53_}})
  else
    local function _54_()
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
      local function _56_(selected)
        local selected_label = selected[1]
        local directive_text = directives.get(selected_label)
        local annotations = concat_list_with_format(state["query-parts"], "==Section Start==", "====", "==Section End==")
        send_keys_to_selected_pane((annotations .. directive_text .. "\n"))
        return clear_annotations()
      end
      return fzf.fzf_exec(lines, {prompt = "Pick a Directive> ", actions = {default = _56_}})
    end
    return choose_pane(parse_panes(shell(panes_command)), _54_)
  end
end
M.FlushWithDirective = _51_
return M
