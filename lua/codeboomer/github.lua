-- [nfnl] codeboomer/github.fnl
vim = vim
local git = require("codeboomer.git")
local review = require("codeboomer.review")
local M = {}
local function notify(msg, level)
  local function _1_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_1_)
end
local function parse_github_slug(url)
  if url then
    local path = url:match("github%.com[:/](.+)")
    local slug
    if path then
      slug = path:gsub("%.git$", "")
    else
      slug = nil
    end
    if slug then
      return slug:match("^[%w%-%_.]+/[%w%-%_.]+$")
    else
      return nil
    end
  else
    return nil
  end
end
local function github_slug()
  local slug = nil
  for _, r in ipairs((git.remotes() or {})) do
    if (not slug and (r.name == "origin")) then
      slug = parse_github_slug(r.url)
    else
    end
  end
  for _, r in ipairs((git.remotes() or {})) do
    if not slug then
      slug = parse_github_slug(r.url)
    else
    end
  end
  return slug
end
local function _7_()
  return github_slug()
end
M["repo-slug"] = _7_
local function parse_pr(stdout)
  local pr = vim.json.decode((stdout or "{}"))
  if pr.number then
    return {number = pr.number, url = pr.url}
  else
    return nil
  end
end
M["pr-for-branch"] = function(_3fbranch, _3fthen)
  local branch = (_3fbranch or git["branch-name"]())
  local slug = github_slug()
  if not branch then
    return notify("codeboomer: detached HEAD \226\128\148 no branch to look up", vim.log.levels.ERROR)
  elseif not slug then
    return notify("codeboomer: no GitHub remote in this repository", vim.log.levels.ERROR)
  else
    local function _9_(obj)
      if _3fthen then
        local function _10_()
          if (obj.code == 0) then
            return parse_pr(obj.stdout)
          else
            return nil
          end
        end
        return _3fthen(_10_())
      else
        return nil
      end
    end
    return vim.system({"gh", "pr", "view", branch, "--repo", slug, "--json", "number,url"}, {text = true}, _9_)
  end
end
local function review_comment(t)
  local bodies
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, c in ipairs(review["comments-for"]((t.id or 0))) do
      local val_28_ = (c.body or "")
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    bodies = tbl_26_
  end
  local pr_comment = {path = (t.file_path or ""), line = (t.line_end or (t.line_start or 1)), body = table.concat(bodies, "\n\n")}
  if (t.line_start and t.line_end and (t.line_start < t.line_end)) then
    pr_comment.start_line = t.line_start
  else
  end
  return pr_comment
end
local function group_by_commit(threads)
  local groups = {}
  for _, t in ipairs(threads) do
    local sha = (review["commit-sha"]((t.anchor_commit or 0)) or "?")
    local bucket = (groups[sha] or {})
    table.insert(bucket, t)
    groups[sha] = bucket
  end
  return groups
end
local function post_review(slug, pr_number, event, sha, threads)
  local comments
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, t in ipairs(threads) do
      local val_28_ = review_comment(t)
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    comments = tbl_26_
  end
  local payload = {body = string.format("codeboomer review \226\128\148 %d thread(s)", #comments), event = event, comments = comments}
  if (sha ~= "?") then
    payload.commit_id = sha
  else
  end
  local function _17_(obj)
    if (obj.code == 0) then
      local res = vim.json.decode((obj.stdout or "{}"))
      local or_18_ = res.html_url
      if not or_18_ then
        local function _20_()
          local t_19_ = res
          if (nil ~= t_19_) then
            t_19_ = t_19_.id
          else
          end
          return t_19_
        end
        or_18_ = tostring(_20_())
      end
      return notify(string.format("codeboomer: posted %d comment(s) \226\128\148 %s", #comments, or_18_), vim.log.levels.INFO)
    else
      return notify(string.format("codeboomer: gh api failed (exit %d)\n%s", obj.code, (obj.stderr or "")), vim.log.levels.ERROR)
    end
  end
  return vim.system({"gh", "api", string.format("repos/%s/pulls/%s/reviews", slug, pr_number), "--input", "-"}, {input = vim.json.encode(payload), text = true}, _17_)
end
M["post-threads"] = function(_3fopts)
  local opts = (_3fopts or {})
  local ok, sid_default = pcall(review["active-session-id"])
  local sid
  local or_23_ = opts["session-id"]
  if not or_23_ then
    if ok then
      or_23_ = sid_default
    else
      or_23_ = nil
    end
  end
  sid = or_23_
  local branch = (opts.branch or git["branch-name"]())
  local slug = github_slug()
  if not ok then
    return notify(("codeboomer: " .. tostring(sid_default)), vim.log.levels.ERROR)
  elseif not slug then
    return notify("codeboomer: no GitHub remote in this repository", vim.log.levels.ERROR)
  elseif not sid then
    return notify("codeboomer: no review session to post", vim.log.levels.WARN)
  else
    local threads = review["threads-for-session"](sid)
    if (0 == #threads) then
      return notify("codeboomer: session has no threads", vim.log.levels.WARN)
    else
      local function _25_(pr)
        if pr then
          for sha, ts in pairs(group_by_commit(threads)) do
            post_review(slug, pr.number, (opts.event or "COMMENT"), sha, ts)
          end
          return nil
        else
          return notify(("codeboomer: no open PR for " .. (branch or "?")), vim.log.levels.WARN)
        end
      end
      return M["pr-for-branch"](branch, _25_)
    end
  end
end
return M
