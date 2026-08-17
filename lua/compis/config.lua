-- [nfnl] fnl/compis/config.fnl
vim = vim
local M = {}
local keymaps = {send = {"n", "<cmd>Compis SendKeys<cr>", "compis: send message to pane"}, send_visual = {"x", ":Compis SendKeys<cr>", "compis: send selection to pane"}, pane = {"n", "<cmd>Compis SetPane<cr>", "compis: pick a tmux pane"}}
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
