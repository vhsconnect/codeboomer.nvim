-- [nfnl] fnl/codeboomer/config.fnl
vim = vim
local M = {}
local directives = require("codeboomer.directives")
local one_offs = require("codeboomer.one-offs")
local keymaps = {send_prompt = {{"n", "x"}, ":Codeboomer SendPrompt<cr>", "codeboomer: send prompt to pane"}, send_selection = {"x", ":Codeboomer SendSelection<cr>", "codeboomer: send selection to pane as-is"}, ask_one_off = {{"n", "x"}, ":Codeboomer AskOneOff<cr>", "codeboomer: run one-off query, reply shown here"}, flush_with_directive = {"n", "<cmd>Codeboomer FlushWithDirective<cr>", "codeboomer: flush annotations with directive to pane"}, pane = {"n", "<cmd>Codeboomer SetPane<cr>", "codeboomer: pick a tmux pane"}, session = {"n", "<cmd>Codeboomer SetSession<cr>", "codeboomer: pick or create the review session"}, review = {"n", "<cmd>Codeboomer Review<cr>", "codeboomer: review a pull request in a read-only worktree"}, review_worktree = {"n", "<cmd>Codeboomer ReviewWorktree<cr>", "codeboomer: review the uncommitted working tree as a snapshot"}, post_review = {"n", "<cmd>Codeboomer PostReview<cr>", "codeboomer: push unposted annotations to the PR"}, pull_review = {"n", "<cmd>Codeboomer PullReview<cr>", "codeboomer: pull the PR's inline comments into the session"}, annotate = {"x", ":Codeboomer Annotate<cr>", "codeboomer: annotate some text"}, comments = {"n", "<cmd>Codeboomer Comments<cr>", "codeboomer: toggle the review comments pane"}, enter_pane = {"n", "<cmd>Codeboomer Enter<cr>", "codeboomer: step into the review comments pane"}}
local function fold_by_label(defaults, entries)
  local effective = vim.list_slice(defaults)
  local index = {}
  for i, entry in ipairs(effective) do
    index[entry.label] = i
  end
  for _, entry in ipairs((entries or {})) do
    if index[entry.label] then
      effective[index[entry.label]] = entry
    else
      table.insert(effective, entry)
    end
  end
  return effective
end
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", (M.config or {}), (opts or {}))
  do
    local prompting = (M.config.prompting or {})
    prompting.one_off_commands = fold_by_label(one_offs.defaults(), prompting.one_off_commands)
    prompting.directives = fold_by_label(directives.defaults(), prompting.directives)
    M.config.prompting = prompting
  end
  for k, _2_ in pairs(keymaps) do
    local mode = _2_[1]
    local rhs = _2_[2]
    local desc = _2_[3]
    local lhs
    do
      local t_3_ = M.config
      if (nil ~= t_3_) then
        t_3_ = t_3_.keybindings
      else
      end
      if (nil ~= t_3_) then
        t_3_ = t_3_[k]
      else
      end
      lhs = t_3_
    end
    if lhs then
      vim.keymap.set(mode, lhs, rhs, {desc = desc})
    else
    end
  end
  return M.config
end
return M
