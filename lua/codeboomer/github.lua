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
local function system(argv, opts, on_exit)
  local function _2_(obj)
    local function _3_()
      return on_exit(obj)
    end
    return vim.schedule(_3_)
  end
  return vim.system(argv, opts, _2_)
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
local function _9_()
  return github_slug()
end
M["repo-slug"] = _9_
local function pr_comment(t, c)
  local item = {path = (t.file_path or ""), line = (t.line_end or (t.line_start or 1)), body = (c.body or "")}
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
  local function _14_(obj)
    if (obj.code == 0) then
      local res = vim.json.decode((obj.stdout or "{}"))
      review["mark-annotations"]("posted", ids)
      local or_15_ = res.html_url
      if not or_15_ then
        local function _17_()
          local t_16_ = res
          if (nil ~= t_16_) then
            t_16_ = t_16_.id
          else
          end
          return t_16_
        end
        or_15_ = tostring(_17_())
      end
      return notify(string.format("codeboomer: posted %d annotation(s) \226\128\148 %s", #comments, or_15_), vim.log.levels.INFO)
    else
      return notify(string.format("codeboomer: gh api failed (exit %d)\n%s", obj.code, (obj.stderr or "")), vim.log.levels.ERROR)
    end
  end
  return system({"gh", "api", string.format("repos/%s/pulls/%s/reviews", slug, pr_number), "--input", "-"}, {stdin = vim.json.encode(payload), text = true}, _14_)
end
local function post_reply(slug, pr_number, a)
  local root = review["gh-root-comment-id"](a.thread.id)
  if not root then
    return notify(string.format("codeboomer: thread #%s has no gh comment to reply to", tostring((a.thread.id or 0))), vim.log.levels.ERROR)
  else
    local function _20_(obj)
      if (obj.code == 0) then
        review["mark-annotations"]("posted", {a.comment.id})
        return notify("codeboomer: reply posted", vim.log.levels.INFO)
      else
        return notify(string.format("codeboomer: reply failed (exit %d)\n%s", obj.code, (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return system({"gh", "api", string.format("repos/%s/pulls/%s/comments/%s/replies", slug, pr_number, root), "--input", "-"}, {stdin = vim.json.encode({body = (a.comment.body or "")}), text = true}, _20_)
  end
end
M["validate-ranges"] = function(pending, ranges)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, a in ipairs((pending or {})) do
    local val_28_
    do
      local t = a.thread
      local rs = (ranges and ranges[(t.file_path or "")])
      local and_23_ = rs
      if and_23_ then
        local hit = false
        for _0, _24_ in ipairs(rs) do
          local s = _24_[1]
          local e = _24_[2]
          hit = (hit or ((s <= (t.line_end or 0)) and (e >= (t.line_start or 0))))
        end
        and_23_ = hit
      end
      if not and_23_ then
        val_28_ = a
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
local function post_pending(session, slug, pending)
  local replies = {}
  local news = {}
  for _, a in ipairs(pending) do
    if review["gh-root-comment-id"](a.thread.id) then
      table.insert(replies, a)
    else
      table.insert(news, a)
    end
  end
  for _, a in ipairs(replies) do
    post_reply(slug, session.pr_number, a)
  end
  for sha, entries in pairs(group_pending(news)) do
    post_review(slug, session.pr_number, "COMMENT", sha, entries)
  end
  return nil
end
local function post_checked(session, sid, slug, ranges)
  local pending = review["pending-annotations"](sid, "posted")
  if (0 == #pending) then
    return notify("codeboomer: nothing to post \226\128\148 no unposted annotations", vim.log.levels.WARN)
  else
    local invalid
    if ranges then
      invalid = M["validate-ranges"](pending, ranges)
    else
      invalid = {}
    end
    if (#invalid > 0) then
      return notify(string.format("codeboomer: %d annotation(s) fall outside the PR diff \226\128\148 move or resolve them first", #invalid), vim.log.levels.ERROR)
    else
      return post_pending(session, slug, pending)
    end
  end
end
M["post-threads"] = function(_3fopts)
  local opts = (_3fopts or {})
  local sid = (opts["session-id"] or review["current-session-id"]())
  local session
  if sid then
    session = review["session-by-id"](sid)
  else
    session = nil
  end
  local slug = github_slug()
  if not sid then
    return notify("codeboomer: no review session \226\128\148 pick one first", vim.log.levels.WARN)
  elseif not session then
    return notify("codeboomer: session not found", vim.log.levels.ERROR)
  elseif not session.pr_number then
    return notify("codeboomer: the chosen session is not a PR review", vim.log.levels.WARN)
  elseif not slug then
    return notify("codeboomer: no GitHub remote in this repository", vim.log.levels.ERROR)
  else
    return post_checked(session, sid, slug, opts.ranges)
  end
end
local function parse_jsonl(out)
  local tbl_26_ = {}
  local i_27_ = 0
  for line in string.gmatch((out or ""), "[^\r\n]+") do
    local val_28_
    do
      local ok, item = pcall(vim.json.decode, line)
      if (ok and ("table" == type(item))) then
        val_28_ = item
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
M["import-items"] = function(session_id, items)
  local n = 0
  for _, item in ipairs((items or {})) do
    if (item.id and not review["comment-by-gh"](item.id)) then
      do
        local parent
        if item.in_reply_to_id then
          parent = review["thread-id-for-gh"](item.in_reply_to_id)
        else
          parent = nil
        end
        if parent then
          review["import-comment"](parent, item)
        else
          review["import-thread"](session_id, item)
        end
      end
      n = (n + 1)
    else
    end
  end
  return n
end
M["pull-comments"] = function(pr_number)
  local slug = github_slug()
  local session = review["session-for-pr"](pr_number)
  if not slug then
    return notify("codeboomer: no GitHub remote in this repository", vim.log.levels.ERROR)
  elseif not session then
    return notify("codeboomer: no session for this PR \226\128\148 :Codeboomer Review it first", vim.log.levels.WARN)
  else
    local function _38_(obj)
      if (obj.code == 0) then
        local n = M["import-items"](session.id, parse_jsonl(obj.stdout))
        vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerImported"})
        return notify(string.format("codeboomer: pulled %d new comment(s)", n), vim.log.levels.INFO)
      else
        return notify(string.format("codeboomer: gh api failed (exit %d)\n%s", obj.code, (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return system({"gh", "api", string.format("repos/%s/pulls/%s/comments", slug, pr_number), "--paginate", "--jq", ".[]"}, {text = true}, _38_)
  end
end
return M
