-- [nfnl] fnl/varubrev/config.fnl
vim = vim
local M = {}
local directives = require("varubrev.directives")
local keymaps = {send = {"n", "<cmd>Varubrev SendKeys<cr>", "varubrev: send message to pane"}, send_visual = {"x", ":Varubrev SendKeys<cr>", "varubrev: send selection to pane"}, pane = {"n", "<cmd>Varubrev SetPane<cr>", "varubrev: pick a tmux pane"}, send_with_directive = {"n", "<cmd>Varubrev SendWithDirective<cr>", "varubrev: Send Keys along with annotations"}, send_visualOO = {"x", ":Varubrev SendKeysOO<cr>", "varubrev: send one off action"}, annotate = {"x", ":Varubrev Annotate<cr>", "varubrev: annotate some text"}}
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", (M.config or {}), (opts or {}))
  do
    local effective = directives.defaults()
    local index = {}
    for i, d in ipairs(effective) do
      index[d.label] = i
    end
    local _2_
    do
      local t_1_ = opts
      if (nil ~= t_1_) then
        t_1_ = t_1_.prompting
      else
      end
      if (nil ~= t_1_) then
        t_1_ = t_1_.directives
      else
      end
      _2_ = t_1_
    end
    for _, d in ipairs((_2_ or {})) do
      if index[d.label] then
        effective[index[d.label]] = d
      else
        table.insert(effective, d)
      end
    end
    M.config["prompting"] = vim.tbl_deep_extend("force", (M.config.prompting or {}), {directives = effective})
  end
  for k, _6_ in pairs(keymaps) do
    local mode = _6_[1]
    local rhs = _6_[2]
    local desc = _6_[3]
    local lhs
    do
      local t_7_ = M.config
      if (nil ~= t_7_) then
        t_7_ = t_7_.keybindings
      else
      end
      if (nil ~= t_7_) then
        t_7_ = t_7_[k]
      else
      end
      lhs = t_7_
    end
    if lhs then
      vim.keymap.set(mode, lhs, rhs, {desc = desc})
    else
    end
  end
  return M.config
end
return M
