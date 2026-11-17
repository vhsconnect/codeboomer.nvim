-- [nfnl] fnl/codeboomer/config.fnl
vim = vim
local M = {}
local directives = require("codeboomer.directives")
local review_agents = require("codeboomer.review-agents")
local launch_processes = require("codeboomer.launch-processes")
local keymaps = {send_prompt = {{"n", "x"}, ":Codeboomer SendPrompt<cr>", "codeboomer: send prompt to pane"}, send_last_prompt = {{"n", "x"}, ":Codeboomer SendLastPrompt<cr>", "codeboomer: resend the last prompt to pane"}, send_selection = {"x", ":Codeboomer SendSelection<cr>", "codeboomer: send selection to pane as-is"}, flush_with_directive = {"n", "<cmd>Codeboomer FlushWithDirective<cr>", "codeboomer: flush annotations with directive to pane"}, pane = {"n", "<cmd>Codeboomer SetPane<cr>", "codeboomer: pick a target pane (tmux or nvim terminal)"}, reset_session = {"n", "<cmd>Codeboomer ResetSession<cr>", "codeboomer: reset this branch's review session"}, review = {"n", "<cmd>Codeboomer Review<cr>", "codeboomer: pick a PR to review on this branch"}, post_review = {"n", "<cmd>Codeboomer PostReview<cr>", "codeboomer: push unposted annotations to the PR"}, pull_review = {"n", "<cmd>Codeboomer PullReview<cr>", "codeboomer: pull the PR's inline comments into the session"}, launch_reviewer = {"n", "<cmd>Codeboomer LaunchReviewer<cr>", "codeboomer: launch a review agent in a terminal buffer"}, launch_process = {"n", "<cmd>Codeboomer LaunchProcess<cr>", "codeboomer: launch a configured process in a terminal"}, pane_toggle = {"n", "<cmd>Codeboomer TogglePane<cr>", "codeboomer: collapse or bring back the pane's terminal"}, sidebar_toggle = {"n", "<cmd>Codeboomer ToggleSidebar<cr>", "codeboomer: collapse or bring back the comments pane"}, annotate = {{"n", "x"}, ":Codeboomer Annotate<cr>", "codeboomer: annotate selection or whole file"}}
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
    prompting.directives = fold_by_label(directives.defaults(), prompting.directives)
    prompting.review_agents = fold_by_label(review_agents.defaults(), prompting.review_agents)
    prompting.launch_processes = fold_by_label(launch_processes.defaults(), prompting.launch_processes)
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
