-- [nfnl] fnl/codeboomer/review-mode.fnl
vim = vim
local git = require("codeboomer.git")
local review = require("codeboomer.review")
local sidebar = require("codeboomer.sidebar")
local github = require("codeboomer.github")
local M = {}
local diff_ranges = {}
local function notify(msg, level)
  local function _1_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_1_)
end
local function run(argv, k)
  local function _2_(obj)
    local function _3_()
      if (obj.code == 0) then
        return k((obj.stdout or ""))
      else
        return notify(("codeboomer: `" .. table.concat(argv, " ") .. "` failed (exit " .. tostring(obj.code) .. ")\n" .. (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return vim.schedule(_3_)
  end
  return vim.system(argv, {text = true}, _2_)
end
local function gh_view(n, k)
  local function _5_(out)
    local ok, pr = pcall(vim.json.decode, out)
    if (ok and ("table" == type(pr)) and pr.number) then
      return k(pr)
    else
      return notify(("codeboomer: `gh pr view " .. tostring(n) .. "` gave nothing usable"), vim.log.levels.ERROR)
    end
  end
  return run({"gh", "pr", "view", tostring(n), "--json", "number,headRefName,headRefOid"}, _5_)
end
local function choose_pr(prs, k)
  local fzf = require("fzf-lua")
  local by_display = {}
  local lines
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, p in ipairs(prs) do
      local val_28_
      do
        local display = string.format("#%-5s %-55s %s", tostring(p.number), (p.title or ""), (p.headRefName or ""))
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
  local function _8_(selected)
    local pr = by_display[selected[1]]
    if pr then
      return k(pr)
    else
      return nil
    end
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a PR> ", actions = {default = _8_}})
end
local function parse_ranges(diff)
  local header_re = "^%+%+%+ b/(.*)"
  local hunk_re = "^@@ %-%d+,?%d* %+(%d+),?(%d*) @@"
  local out = {}
  local file = nil
  for line in string.gmatch((diff or ""), "[^\n]+") do
    local header = string.match(line, header_re)
    if (header and (header ~= "/dev/null")) then
      file = header
    else
    end
    local c, d = string.match(line, hunk_re)
    if (file and c) then
      local start = tonumber(c)
      local count
      local function _11_()
        if (not d or (d == "")) then
          return "1"
        else
          return d
        end
      end
      count = tonumber(_11_())
      if (count > 0) then
        local bucket = (out[file] or {})
        table.insert(bucket, {start, (start + count + -1)})
        out[file] = bucket
      else
      end
    else
    end
  end
  return out
end
local function diff_argv(pr_number)
  return {"gh", "pr", "diff", tostring(pr_number), "--color=never"}
end
local function load_ranges(pr_number)
  local function _14_(obj)
    local function _15_()
      local _16_
      if (obj.code == 0) then
        _16_ = parse_ranges(obj.stdout)
      else
        _16_ = false
      end
      diff_ranges[pr_number] = _16_
      return nil
    end
    return vim.schedule(_15_)
  end
  return vim.system(diff_argv(pr_number), {text = true}, _14_)
end
local function ranges_for(pr_number)
  if (nil == diff_ranges[pr_number]) then
    local obj = vim.system(diff_argv(pr_number), {text = true}):wait(10000)
    local _18_
    if (obj.code == 0) then
      _18_ = parse_ranges(obj.stdout)
    else
      _18_ = false
    end
    diff_ranges[pr_number] = _18_
  else
  end
  return (diff_ranges[pr_number] or nil)
end
M["promote-context"] = function(session)
  if (session and session.pr_number) then
    return {["session-id"] = session.id, ["head-ranges"] = ranges_for(session.pr_number)}
  else
    return nil
  end
end
local function pr_branch_3f(branch, pr)
  local merge = git["merge-ref"](branch)
  return ((branch == pr.headRefName) or (merge == ("refs/heads/" .. (pr.headRefName or ""))) or (merge == string.format("refs/pull/%d/head", pr.number)) or ((nil ~= pr.headRefOid) and (git["head-sha"]() == pr.headRefOid)))
end
local function open_pr(pr)
  local branch = git["branch-name"]()
  local bound
  do
    local t_22_ = review["session-for"]()
    if (nil ~= t_22_) then
      t_22_ = t_22_.pr_number
    else
    end
    bound = t_22_
  end
  if not branch then
    return notify(string.format("codeboomer: check out PR #%d's branch `%s` first \226\128\148 sessions are tied to branches, a detached HEAD has none", pr.number, (pr.headRefName or "?")), vim.log.levels.ERROR)
  elseif not pr_branch_3f(branch, pr) then
    return notify(string.format("codeboomer: PR #%d is for branch `%s`, but `%s` is checked out and neither tracks it nor sits on its head commit \226\128\148 check out `%s` first", pr.number, (pr.headRefName or "?"), branch, (pr.headRefName or "?")), vim.log.levels.ERROR)
  elseif (bound and (bound ~= pr.number)) then
    return notify(string.format("codeboomer: this branch's session is bound to PR #%d \226\128\148 :Codeboomer ResetSession first to review PR #%d", bound, pr.number), vim.log.levels.ERROR)
  else
    local session_id = review["ensure-session"]()
    review["set-session-pr"](session_id, pr.number)
    sidebar.open()
    github["pull-comments"](pr.number, session_id)
    return load_ranges(pr.number)
  end
end
local function _25_(_3fn)
  if not git["repo-root"]() then
    return notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
  else
    if _3fn then
      return gh_view(_3fn, open_pr)
    else
      local function _26_(out)
        local ok, prs = pcall(vim.json.decode, out)
        if (ok and ("table" == type(prs)) and (#prs > 0)) then
          return choose_pr(prs, open_pr)
        else
          return notify("codeboomer: no open PRs (or `gh` unavailable)", vim.log.levels.WARN)
        end
      end
      return run({"gh", "pr", "list", "--json", "number,title,headRefName,headRefOid"}, _26_)
    end
  end
end
M.open = _25_
local function _30_()
  local sid = sidebar["session-id"]()
  local session
  if sid then
    session = review["session-by-id"](sid)
  else
    session = nil
  end
  local _32_
  local _34_
  do
    local t_33_ = session
    if (nil ~= t_33_) then
      t_33_ = t_33_.pr_number
    else
    end
    _34_ = t_33_
  end
  if _34_ then
    _32_ = ranges_for(session.pr_number)
  else
    _32_ = nil
  end
  return github["post-threads"]({["session-id"] = sid, ranges = _32_})
end
M.post = _30_
local function _37_()
  local sid = sidebar["session-id"]()
  local session
  if sid then
    session = review["session-by-id"](sid)
  else
    session = nil
  end
  if (session and session.pr_number) then
    return github["pull-comments"](session.pr_number, sid)
  else
    return notify("codeboomer: this branch's session is not bound to a PR \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
  end
end
M.pull = _37_
M["parse-ranges"] = parse_ranges
return M
