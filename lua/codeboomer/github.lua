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
local function pr_comment(t, c)
  local item = {path = (t.file_path or ""), body = (c.body or "")}
  if ("file" == (t.type or "line")) then
    item.subject_type = "file"
  else
    item.side = "RIGHT"
    item.line = (t.line_end or (t.line_start or 1))
    if (t.line_start and t.line_end and (t.line_start < t.line_end)) then
      item.start_line = t.line_start
      item.start_side = "RIGHT"
    else
    end
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
local function post_review(slug, pr_number, sha, entries)
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
  local payload = {body = string.format("codeboomer review \226\128\148 %d annotation(s)", #comments), comments = comments}
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
      return notify(string.format("codeboomer: drafted %d annotation(s) \226\128\148 pending review, submit it on GitHub\n%s", #comments, or_15_), vim.log.levels.INFO)
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
        local ok, res = pcall(vim.json.decode, (obj.stdout or "{}"))
        local gh_id
        if (ok and ("table" == type(res))) then
          gh_id = res.id
        else
          gh_id = nil
        end
        review["mark-annotations"]("posted", {a.comment.id})
        if gh_id then
          review["stamp-gh-comment"](a.comment.id, gh_id)
        else
        end
        return notify("codeboomer: reply posted", vim.log.levels.INFO)
      else
        return notify(string.format("codeboomer: reply failed (exit %d)\n%s", obj.code, (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return system({"gh", "api", string.format("repos/%s/pulls/%s/comments/%s/replies", slug, pr_number, root), "--input", "-"}, {stdin = vim.json.encode({body = (a.comment.body or "")}), text = true}, _20_)
  end
end
local function _25_(t, ranges)
  if ("file" == (t.type or "line")) then
    return false
  else
    local rs = (ranges and ranges[(t.file_path or "")])
    local and_26_ = rs
    if and_26_ then
      local hit = false
      for _, _27_ in ipairs(rs) do
        local s = _27_[1]
        local e = _27_[2]
        hit = (hit or ((s <= (t.line_end or 0)) and (e >= (t.line_start or 0))))
      end
      and_26_ = hit
    end
    return not and_26_
  end
end
M["thread-off-diff"] = _25_
M["validate-ranges"] = function(pending, ranges)
  local tbl_26_ = {}
  local i_27_ = 0
  for _, a in ipairs((pending or {})) do
    local val_28_
    if M["thread-off-diff"](a.thread, ranges) then
      val_28_ = a
    else
      val_28_ = nil
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
    post_review(slug, session.pr_number, sha, entries)
  end
  return nil
end
local function post_checked(session, sid, slug, ranges)
  local pending = review["pending-for-post"](sid)
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
  local sid = opts["session-id"]
  local session
  if sid then
    session = review["session-by-id"](sid)
  else
    session = nil
  end
  local slug = github_slug()
  if not sid then
    return notify("codeboomer: no session for this branch \226\128\148 annotate first", vim.log.levels.WARN)
  elseif not session then
    return notify("codeboomer: session not found", vim.log.levels.ERROR)
  elseif not session.pr_number then
    return notify("codeboomer: this branch's session is not bound to a PR \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
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
      local parent
      if item.in_reply_to_id then
        parent = review["thread-id-for-gh"](item.in_reply_to_id)
      else
        parent = nil
      end
      local mine
      if not item.in_reply_to_id then
        mine = review["match-posted-comment"](session_id, item)
      else
        mine = nil
      end
      if mine then
        review["stamp-gh-comment"](mine.id, item.id)
      else
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
M["pull-comments"] = function(pr_number, sid)
  local slug = github_slug()
  local session
  if sid then
    session = review["session-by-id"](sid)
  else
    session = nil
  end
  if not slug then
    return notify("codeboomer: no GitHub remote in this repository", vim.log.levels.ERROR)
  elseif (not session or (session.pr_number ~= pr_number)) then
    return notify("codeboomer: this branch's session is not bound to the PR \226\128\148 :Codeboomer Review it first", vim.log.levels.WARN)
  else
    local function _45_(obj)
      if (obj.code == 0) then
        local n = M["import-items"](session.id, parse_jsonl(obj.stdout))
        vim.api.nvim_exec_autocmds("User", {pattern = "CodeboomerImported"})
        return notify(string.format("codeboomer: pulled %d new comment(s)", n), vim.log.levels.INFO)
      else
        return notify(string.format("codeboomer: gh api failed (exit %d)\n%s", obj.code, (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return system({"gh", "api", string.format("repos/%s/pulls/%s/comments", slug, pr_number), "--paginate", "--jq", ".[]"}, {text = true}, _45_)
  end
end
return M
