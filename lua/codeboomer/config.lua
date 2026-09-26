-- [nfnl] fnl/codeboomer/config.fnl
vim = vim
local M = {}
local directives = require("codeboomer.directives")
local one_offs = require("codeboomer.one-offs")
local keymaps = {send_prompt = {{"n", "x"}, ":Codeboomer SendPrompt<cr>", "codeboomer: send prompt to pane"}, send_selection = {"x", ":Codeboomer SendSelection<cr>", "codeboomer: send selection to pane as-is"}, ask_one_off = {{"n", "x"}, ":Codeboomer AskOneOff<cr>", "codeboomer: run one-off query, reply shown here"}, flush_with_directive = {"n", "<cmd>Codeboomer FlushWithDirective<cr>", "codeboomer: flush annotations with directive to pane"}, pane = {"n", "<cmd>Codeboomer SetPane<cr>", "codeboomer: pick a tmux pane"}, session = {"n", "<cmd>Codeboomer Sessions<cr>", "codeboomer: manage review sessions (d deletes)"}, review = {"n", "<cmd>Codeboomer Review<cr>", "codeboomer: review a pull request in a read-only worktree"}, review_worktree = {"n", "<cmd>Codeboomer ReviewWorktree<cr>", "codeboomer: review the uncommitted working tree as a snapshot"}, review_side = {"n", "<cmd>Codeboomer ReviewSide<cr>", "codeboomer: toggle the review between new and old code"}, walk_forward = {"n", "<cmd>Codeboomer WalkForward<cr>", "codeboomer: walk the review forward one commit"}, walk_back = {"n", "<cmd>Codeboomer WalkBack<cr>", "codeboomer: walk the review back one commit"}, post_review = {"n", "<cmd>Codeboomer PostReview<cr>", "codeboomer: push unposted annotations to the PR"}, pull_review = {"n", "<cmd>Codeboomer PullReview<cr>", "codeboomer: pull the PR's inline comments into the session"}, annotate = {{"n", "x"}, ":Codeboomer Annotate<cr>", "codeboomer: annotate selection or whole file"}}
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
M["debug?"] = function()
  local t_2_ = M
  if (nil ~= t_2_) then
    t_2_ = t_2_.config
  else
  end
  if (nil ~= t_2_) then
    t_2_ = t_2_.debug
  else
  end
  return t_2_
end
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", (M.config or {}), (opts or {}))
  do
    local prompting = (M.config.prompting or {})
    prompting.one_off_commands = fold_by_label(one_offs.defaults(), prompting.one_off_commands)
    prompting.directives = fold_by_label(directives.defaults(), prompting.directives)
    M.config.prompting = prompting
  end
  for k, _5_ in pairs(keymaps) do
    local mode = _5_[1]
    local rhs = _5_[2]
    local desc = _5_[3]
    local lhs
    do
      local t_6_ = M.config
      if (nil ~= t_6_) then
        t_6_ = t_6_.keybindings
      else
      end
      if (nil ~= t_6_) then
        t_6_ = t_6_[k]
      else
      end
      lhs = t_6_
    end
    if lhs then
      vim.keymap.set(mode, lhs, rhs, {desc = desc})
    else
    end
  end
  return M.config
end
return M
