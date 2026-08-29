-- [nfnl] codeboomer/config.fnl
vim = vim
local M = {}
local directives = require("codeboomer.directives")
local keymaps = {send_prompt = {{"n", "x"}, ":Codeboomer SendPrompt<cr>", "codeboomer: send prompt to pane"}, send_selection = {"x", ":Codeboomer SendSelection<cr>", "codeboomer: send selection to pane as-is"}, ask_one_off = {{"n", "x"}, ":Codeboomer AskOneOff<cr>", "codeboomer: run one-off query, reply shown here"}, flush_with_directive = {"n", "<cmd>Codeboomer FlushWithDirective<cr>", "codeboomer: flush annotations with directive to pane"}, pane = {"n", "<cmd>Codeboomer SetPane<cr>", "codeboomer: pick a tmux pane"}, annotate = {"x", ":Codeboomer Annotate<cr>", "codeboomer: annotate some text"}}
local default_one_off_command = {"claude-code", "--model", "haiku", "--output-format", "json", "--permission-mode", "acceptEdits", "-p"}
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", (M.config or {}), (opts or {}))
  do
    local prompting = (M.config.prompting or {})
    if not prompting.one_off_command then
      prompting.one_off_command = vim.list_slice(default_one_off_command)
    else
    end
    do
      local effective = directives.defaults()
      local index = {}
      for i, d in ipairs(effective) do
        index[d.label] = i
      end
      local _3_
      do
        local t_2_ = opts
        if (nil ~= t_2_) then
          t_2_ = t_2_.prompting
        else
        end
        if (nil ~= t_2_) then
          t_2_ = t_2_.directives
        else
        end
        _3_ = t_2_
      end
      for _, d in ipairs((_3_ or {})) do
        if index[d.label] then
          effective[index[d.label]] = d
        else
          table.insert(effective, d)
        end
      end
      prompting.directives = effective
    end
    M.config.prompting = prompting
  end
  for k, _7_ in pairs(keymaps) do
    local mode = _7_[1]
    local rhs = _7_[2]
    local desc = _7_[3]
    local lhs
    do
      local t_8_ = M.config
      if (nil ~= t_8_) then
        t_8_ = t_8_.keybindings
      else
      end
      if (nil ~= t_8_) then
        t_8_ = t_8_[k]
      else
      end
      lhs = t_8_
    end
    if lhs then
      vim.keymap.set(mode, lhs, rhs, {desc = desc})
    else
    end
  end
  return M.config
end
return M
