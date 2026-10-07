-- [nfnl] fnl/codeboomer/reviewer.fnl
vim = vim
local agent = require("codeboomer.agent")
local git = require("codeboomer.git")
local picker = require("codeboomer.picker")
local review_agents = require("codeboomer.review-agents")
local review_mode = require("codeboomer.review-mode")
local tmux = require("codeboomer.tmux")
local M = {}
local commit_pick_limit = 100
local empty_tree = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
local function notify(msg, level)
  local function _1_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_1_)
end
local function choose_agent(agents, k)
  if (1 == #agents) then
    return k(agents[1])
  else
    local function _2_(_241)
      return string.format("%-16s %s", _241.label, table.concat(_241.argv, " "))
    end
    return picker.choose("Review agent> ", agents, _2_, k)
  end
end
local function commits(root)
  local out = git.run(root, "log", "--first-parent", "--format=%h%x09%H%x09%s%x09%an, %ar", "-n", tostring(commit_pick_limit))
  local tbl_26_ = {}
  local i_27_ = 0
  for line in string.gmatch((out or ""), "[^\n]+") do
    local val_28_
    do
      local short, sha, subject, by = string.match(line, "^([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
      if sha then
        val_28_ = {short = short, sha = sha, subject = subject, by = by}
      else
        val_28_ = nil
      end
    end
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
local function root_commit_3f(root, sha)
  return (nil == git.run(root, "rev-parse", "--verify", "-q", (sha .. "^")))
end
local function choose_commit(root, k)
  local function _6_(_241)
    return string.format("%s  %s  (%s)", _241.short, _241.subject, _241.by)
  end
  local function _7_(_241)
    return k({from = _241.sha, short = _241.short, root = root_commit_3f(root, _241.sha)})
  end
  return picker.choose("Review from commit (inclusive)> ", commits(root), _6_, _7_)
end
local function dirty_3f(root)
  return ("" ~= (git.run(root, "status", "--porcelain") or ""))
end
local scopes = {{kind = "pr", label = "GitHub PR \226\128\148 pick this branch's pull request"}, {kind = "uncommitted", label = "Uncommitted \226\128\148 staged, unstaged and untracked changes"}, {kind = "commits", label = "Commits \226\128\148 pick how far back to go"}}
local function choose_scope(root, k)
  local pick
  local function _8_(scope)
    local case_9_ = scope.kind
    if (case_9_ == "pr") then
      local function _10_(_241)
        return k({pr = _241.number, ["base-ref"] = _241.baseRefName})
      end
      return review_mode.open(nil, _10_)
    elseif (case_9_ == "uncommitted") then
      if dirty_3f(root) then
        return k({uncommitted = true})
      else
        return notify("codeboomer: nothing uncommitted to review", vim.log.levels.WARN)
      end
    elseif (case_9_ == "commits") then
      return choose_commit(root, k)
    else
      return nil
    end
  end
  pick = _8_
  local function _13_(_241)
    return _241.label
  end
  return picker.choose("Review what> ", scopes, _13_, pick)
end
local function scope_text(branch, scope)
  if ((_G.type(scope) == "table") and (nil ~= scope.pr)) then
    local n = scope.pr
    return string.format("Review pull request #%d (`gh pr diff %d`), checked out here on branch %s.", n, n, branch)
  elseif ((_G.type(scope) == "table") and (scope.uncommitted == true)) then
    return string.format("Review the uncommitted changes on branch %s \226\128\148 `git diff HEAD` plus the untracked files `git status` lists.", branch)
  elseif ((_G.type(scope) == "table") and (nil ~= scope.short) and (scope.root == true)) then
    local short = scope.short
    return string.format("Review every commit on branch %s from the root commit %s through HEAD (`git diff %s HEAD`).", branch, short, empty_tree)
  elseif ((_G.type(scope) == "table") and (nil ~= scope.short) and (nil ~= scope.from)) then
    local short = scope.short
    local from = scope.from
    return string.format("Review the commits on branch %s from %s (inclusive) through HEAD (`git log -p --first-parent %s~1..HEAD`).", branch, short, from)
  else
    return nil
  end
end
local function pr_base(root, base_ref)
  return (git.run(root, "merge-base", "HEAD", ("origin/" .. base_ref)) or git.run(root, "merge-base", "HEAD", base_ref))
end
local function diff_base(root, scope)
  if ((_G.type(scope) == "table") and true and (nil ~= scope["base-ref"])) then
    local _ = scope.pr
    local base_ref = scope["base-ref"]
    return pr_base(root, base_ref)
  elseif ((_G.type(scope) == "table") and (scope.uncommitted == true)) then
    return "HEAD"
  elseif ((_G.type(scope) == "table") and (scope.root == true)) then
    return empty_tree
  elseif ((_G.type(scope) == "table") and (nil ~= scope.from)) then
    local from = scope.from
    return (from .. "^")
  else
    return nil
  end
end
local function changed_files(root, base)
  local lines
  local function _16_(_241)
    local tbl_26_ = {}
    local i_27_ = 0
    for l in string.gmatch((_241 or ""), "[^\n]+") do
      local val_28_ = l
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    return tbl_26_
  end
  lines = _16_
  local tracked = lines(git.run(root, "diff", "--name-only", base))
  local untracked = lines(git.run(root, "ls-files", "--others", "--exclude-standard"))
  return vim.list_extend(tracked, untracked)
end
local function changes_to_quickfix(root, base)
  local _18_
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, f in ipairs(changed_files(root, base)) do
      local val_28_ = {filename = vim.fs.joinpath(root, f), lnum = 1}
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    _18_ = tbl_26_
  end
  vim.fn.setqflist({}, " ", {title = ("Changes since " .. base), items = _18_})
  return vim.cmd.copen()
end
local function follow_in_gitsigns(root, scope)
  local case_20_, case_21_ = pcall(require, "gitsigns")
  if ((case_20_ == true) and (nil ~= case_21_)) then
    local gitsigns = case_21_
    local case_22_ = diff_base(root, scope)
    if (case_22_ == nil) then
      return notify("codeboomer: no diff base for this review \226\128\148 gitsigns left alone", vim.log.levels.WARN)
    elseif (nil ~= case_22_) then
      local base = case_22_
      local function _23_(err)
        if err then
          return vim.notify(("codeboomer: gitsigns base " .. base .. ": " .. err), vim.log.levels.ERROR)
        else
          return changes_to_quickfix(root, base)
        end
      end
      return gitsigns.change_base(base, true, vim.schedule_wrap(_23_))
    else
      return nil
    end
  else
    return nil
  end
end
local function spawn(root, branch, agent_cmd, scope, on_pane)
  local prompt = agent["review-prompt"](scope_text(branch, scope))
  local argv = vim.list_extend(vim.list_slice(agent_cmd.argv), {prompt})
  local case_27_, case_28_ = tmux["new-window"](root, ("review:" .. branch), argv)
  if ((case_27_ == nil) and (nil ~= case_28_)) then
    local err = case_28_
    return notify(("codeboomer: LaunchReviewer failed: " .. err), vim.log.levels.ERROR)
  elseif (nil ~= case_27_) then
    local pane_id = case_27_
    on_pane((tmux["pane-by-id"](pane_id) or {["pane-id"] = pane_id, ["pane-mode"] = ""}))
    follow_in_gitsigns(root, scope)
    return notify(string.format("codeboomer: %s reviewer launched in pane %s", agent_cmd.label, pane_id), vim.log.levels.INFO)
  else
    return nil
  end
end
M.launch = function(on_pane)
  local root = git["work-root"]()
  local branch = git["branch-name"]()
  local agents = (review_agents.list() or {})
  if (0 == #agents) then
    return notify("codeboomer: prompting.review_agents not set \226\128\148 call setup() first", vim.log.levels.ERROR)
  elseif not root then
    return notify("codeboomer: LaunchReviewer needs a repo file", vim.log.levels.ERROR)
  elseif not branch then
    return notify("codeboomer: LaunchReviewer needs a checked-out branch", vim.log.levels.ERROR)
  else
    local function _30_(agent_cmd)
      local function _31_(_241)
        return spawn(root, branch, agent_cmd, _241, on_pane)
      end
      return choose_scope(root, _31_)
    end
    return choose_agent(agents, _30_)
  end
end
return M
