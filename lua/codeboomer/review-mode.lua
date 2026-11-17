-- [nfnl] fnl/codeboomer/review-mode.fnl
vim = vim
local git = require("codeboomer.git")
local review = require("codeboomer.review")
local sidebar = require("codeboomer.sidebar")
local github = require("codeboomer.github")
local picker = require("codeboomer.picker")
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
  return run({"gh", "pr", "view", tostring(n), "--json", "number,headRefName,headRefOid,baseRefName"}, _5_)
end
local function choose_pr(prs, k)
  local function _7_(_241)
    return string.format("#%-5s %-55s %s", tostring(_241.number), (_241.title or ""), (_241.headRefName or ""))
  end
  return picker.choose("Pick a PR> ", prs, _7_, k)
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
      local function _9_()
        if (not d or (d == "")) then
          return "1"
        else
          return d
        end
      end
      count = tonumber(_9_())
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
  local function _12_(obj)
    local function _13_()
      local _14_
      if (obj.code == 0) then
        _14_ = parse_ranges(obj.stdout)
      else
        _14_ = false
      end
      diff_ranges[pr_number] = _14_
      return nil
    end
    return vim.schedule(_13_)
  end
  return vim.system(diff_argv(pr_number), {text = true}, _12_)
end
local function ranges_for(pr_number)
  if (nil == diff_ranges[pr_number]) then
    local obj = vim.system(diff_argv(pr_number), {text = true}):wait(10000)
    local _16_
    if (obj.code == 0) then
      _16_ = parse_ranges(obj.stdout)
    else
      _16_ = false
    end
    diff_ranges[pr_number] = _16_
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
local function open_pr(pr, _3fthen)
  local branch = git["branch-name"]()
  local bound
  do
    local t_20_ = review["session-for"]()
    if (nil ~= t_20_) then
      t_20_ = t_20_.pr_number
    else
    end
    bound = t_20_
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
    load_ranges(pr.number)
    if _3fthen then
      return _3fthen(pr)
    else
      return nil
    end
  end
end
local function _24_(_3fn, _3fthen)
  local open
  local function _25_(_241)
    return open_pr(_241, _3fthen)
  end
  open = _25_
  if not git["repo-root"]() then
    return notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
  else
    if _3fn then
      return gh_view(_3fn, open)
    else
      local function _26_(out)
        local ok, prs = pcall(vim.json.decode, out)
        if (ok and ("table" == type(prs)) and (#prs > 0)) then
          return choose_pr(prs, open)
        else
          return notify("codeboomer: no open PRs (or `gh` unavailable)", vim.log.levels.WARN)
        end
      end
      return run({"gh", "pr", "list", "--json", "number,title,headRefName,headRefOid,baseRefName"}, _26_)
    end
  end
end
M.open = _24_
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
