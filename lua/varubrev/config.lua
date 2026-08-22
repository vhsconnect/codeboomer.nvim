-- [nfnl] fnl/varubrev/config.fnl
vim = vim
local M = {}
local keymaps = {send = {"n", "<cmd>Varubrev SendKeys<cr>", "varubrev: send message to pane"}, send_visual = {"x", ":Varubrev SendKeys<cr>", "varubrev: send selection to pane"}, pane = {"n", "<cmd>Varubrev SetPane<cr>", "varubrev: pick a tmux pane"}, send_with_directive = {"n", "<cmd>Varubrev SendWithDirective<cr>", "varubrev: Send Keys along with annotations"}, send_visualOO = {"x", ":Varubrev SendKeysOO<cr>", "varubrev: send one off action"}, annotate = {"x", ":Varubrev Annotate<cr>", "varubrev: annotate some text"}}
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", (M.config or {}), (opts or {}))
  for k, _1_ in pairs(keymaps) do
    local mode = _1_[1]
    local rhs = _1_[2]
    local desc = _1_[3]
    if M.config[k] then
      vim.keymap.set(mode, M.config[k], rhs, {desc = desc})
    else
    end
  end
  return M.config
end
return M
