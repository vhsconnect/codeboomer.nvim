-- [nfnl] fnl/codeboomer/review-mode.fnl
vim = vim
local git = require("codeboomer.git")
local review = require("codeboomer.review")
local sidebar = require("codeboomer.sidebar")
local github = require("codeboomer.github")
local M = {}
local current = nil
local function _1_(session)
  if (session and session.pr_number) then
    if (current and (session.id == current["session-id"])) then
      return {["session-id"] = session.id, ["head-ranges"] = current.ranges}
    else
      return {["session-id"] = session.id}
    end
  else
    return nil
  end
end
sidebar["set-promote-context"](_1_)
local function notify(msg, level)
  local function _4_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_4_)
end
local function run(argv, k)
  local function _5_(obj)
    local function _6_()
      if (obj.code == 0) then
        return k((obj.stdout or ""))
      else
        return notify(("codeboomer: `" .. table.concat(argv, " ") .. "` failed (exit " .. tostring(obj.code) .. ")\n" .. (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return vim.schedule(_6_)
  end
  return vim.system(argv, {text = true}, _5_)
end
local function gh_view(n, k)
  local function _8_(out)
    local ok, pr = pcall(vim.json.decode, out)
    if (ok and ("table" == type(pr)) and pr.number) then
      return k(pr)
    else
      return notify(("codeboomer: `gh pr view " .. tostring(n) .. "` gave nothing usable"), vim.log.levels.ERROR)
    end
  end
  return run({"gh", "pr", "view", tostring(n), "--json", "number"}, _8_)
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
  local function _11_(selected)
    local pr = by_display[selected[1]]
    if pr then
      return k(pr)
    else
      return nil
    end
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a PR> ", actions = {default = _11_}})
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
      local function _14_()
        if (not d or (d == "")) then
          return "1"
        else
          return d
        end
      end
      count = tonumber(_14_())
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
local function load_ranges(pr_number)
  local function _17_(out)
    current.ranges = parse_ranges(out)
    return nil
  end
  return run({"gh", "pr", "diff", tostring(pr_number), "--color=never"}, _17_)
end
local function open_pr(pr)
  local session_id = review["ensure-session"]()
  if not session_id then
    return notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
  else
    review["set-session-pr"](session_id, pr.number)
    current = {["pr-number"] = pr.number, ["session-id"] = session_id}
    sidebar.open()
    github["pull-comments"](pr.number, session_id)
    return load_ranges(pr.number)
  end
end
local function _19_(_3fn)
  if not git["repo-root"]() then
    return notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
  else
    if _3fn then
      return gh_view(_3fn, open_pr)
    else
      local function _20_(out)
        local ok, prs = pcall(vim.json.decode, out)
        if (ok and ("table" == type(prs)) and (#prs > 0)) then
          return choose_pr(prs, open_pr)
        else
          return notify("codeboomer: no open PRs (or `gh` unavailable)", vim.log.levels.WARN)
        end
      end
      return run({"gh", "pr", "list", "--json", "number,title,headRefName"}, _20_)
    end
  end
end
M.open = _19_
local function _24_()
  local sid = sidebar["session-id"]()
  local session
  if sid then
    session = review["session-by-id"](sid)
  else
    session = nil
  end
  local _26_
  if (session and current and (session.id == current["session-id"])) then
    _26_ = current.ranges
  else
    _26_ = nil
  end
  return github["post-threads"]({["session-id"] = sid, ranges = _26_})
end
M.post = _24_
local function _28_()
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
M.pull = _28_
M["parse-ranges"] = parse_ranges
return M
