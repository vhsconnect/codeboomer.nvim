-- [nfnl] fnl/codeboomer/tmux.fnl
vim = vim
local M = {}
local function shell(command)
  local handle = io.popen(command)
  local output = handle:read("*a")
  handle:close()
  return output
end
local panes_command = "tmux list-panes -a -F '#{session_name}|#{session_id}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_mode}|#{pane_active}|#{window_active}|#{pane_current_path}'"
local last_lines_command = "tmux list-panes -a -F '#{pane_id}' | while read -r p; do printf '%s\\t' \"$p\"; tmux capture-pane -p -t \"$p\" -S -5 -E -1 2>/dev/null | sed -e '/^[[:space:]]*$/d' | tail -n 1; echo; done"
M["preview-command"] = "tmux capture-pane -p -t {1} -S -40"
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
M["list-panes"] = function()
  return parse_panes(shell(panes_command))
end
M["last-lines"] = function()
  return parse_last_lines(shell(last_lines_command))
end
M["pane-by-id"] = function(pane_id)
  local found = nil
  for _, p in ipairs(M["list-panes"]()) do
    if found then break end
    if (p["pane-id"] == pane_id) then
      found = p
    else
      found = nil
    end
  end
  return found
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
M.send = function(pane, text)
  local pane_id = pane["pane-id"]
  if ("" ~= (pane["pane-mode"] or "")) then
    shell(cancel_mode_command(pane_id))
  else
  end
  paste_text(pane_id, text)
  return shell(press_key_command(pane_id, "Enter"))
end
M["new-window"] = function(cwd, name, argv)
  local res = vim.system(vim.list_extend({"tmux", "new-window", "-d", "-P", "-F", "#{pane_id}", "-c", cwd, "-n", name, "--"}, argv), {text = true}):wait()
  if (0 == res.code) then
    return vim.trim((res.stdout or ""))
  else
    return nil, vim.trim((res.stderr or ""))
  end
end
return M
