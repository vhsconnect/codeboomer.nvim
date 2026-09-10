-- [nfnl] fnl/codeboomer/github.fnl
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
local function rel_path(path)
  local root = git["repo-root"]()
  if (root and path and (1 == path:find((root .. "/"), 1, true))) then
    return path:sub((2 + #root))
  else
    return (path or "")
  end
end
local function pr_comment(t, c)
  local item = {path = rel_path(t.file_path), line = (t.line_end or (t.line_start or 1)), body = (c.body or "")}
  if (t.line_start and t.line_end and (t.line_start < t.line_end)) then
    item.start_line = t.line_start
  else
  end
  return item
end
local function group_pending(pending)
  local groups = {}
  for _, a in ipairs(pending) do
    local sha = (review["commit-sha"]((a.thread.anchor_commit or 0)) or "?")
    local entry = {item = pr_comment(a.thread, a.comment), id = a.comment.id}
    local bucket = (groups[sha] or {})
    table.insert(bucket, entry)
    groups[sha] = bucket
  end
  return groups
end
local function post_review(slug, pr_number, event, sha, entries)
  local comments
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, e in ipairs(entries) do
      local val_28_ = e.item
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    comments = tbl_26_
  end
  local ids
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, e in ipairs(entries) do
      local val_28_ = e.id
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    ids = tbl_26_
  end
  local payload = {body = string.format("codeboomer review \226\128\148 %d annotation(s)", #comments), event = event, comments = comments}
  if (sha ~= "?") then
    payload.commit_id = sha
  else
  end
  local function _18_(obj)
    if (obj.code == 0) then
      local res = vim.json.decode((obj.stdout or "{}"))
      review["mark-annotations"]("posted", ids)
      local or_19_ = res.html_url
      if not or_19_ then
        local function _21_()
          local t_20_ = res
          if (nil ~= t_20_) then
            t_20_ = t_20_.id
          else
          end
          return t_20_
        end
        or_19_ = tostring(_21_())
      end
      return notify(string.format("codeboomer: posted %d annotation(s) \226\128\148 %s", #comments, or_19_), vim.log.levels.INFO)
    else
      return notify(string.format("codeboomer: gh api failed (exit %d)\n%s", obj.code, (obj.stderr or "")), vim.log.levels.ERROR)
    end
  end
  return vim.system({"gh", "api", string.format("repos/%s/pulls/%s/reviews", slug, pr_number), "--input", "-"}, {input = vim.json.encode(payload), text = true}, _18_)
end
M["post-threads"] = function(_3fopts)
  local opts = (_3fopts or {})
  local ok, sid_default = pcall(review["active-session-id"])
  local sid
  local or_24_ = opts["session-id"]
  if not or_24_ then
    if ok then
      or_24_ = sid_default
    else
      or_24_ = nil
    end
  end
  sid = or_24_
  local branch = (opts.branch or git["branch-name"]())
  local slug = github_slug()
  if not ok then
    return notify(("codeboomer: " .. tostring(sid_default)), vim.log.levels.ERROR)
  elseif not slug then
    return notify("codeboomer: no GitHub remote in this repository", vim.log.levels.ERROR)
  elseif not sid then
    return notify("codeboomer: no review session to post", vim.log.levels.WARN)
  else
    local pending = review["pending-annotations"](sid, "posted")
    if (0 == #pending) then
      return notify("codeboomer: nothing to post \226\128\148 no unposted annotations", vim.log.levels.WARN)
    else
      local function _26_(pr)
        if pr then
          for sha, entries in pairs(group_pending(pending)) do
            post_review(slug, pr.number, (opts.event or "COMMENT"), sha, entries)
          end
          return nil
        else
          return notify(("codeboomer: no open PR for " .. (branch or "?")), vim.log.levels.WARN)
        end
      end
      return M["pr-for-branch"](branch, _26_)
    end
  end
end
return M
