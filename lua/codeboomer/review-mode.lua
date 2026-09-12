-- [nfnl] fnl/codeboomer/review-mode.fnl
vim = vim
local git = require("codeboomer.git")
local review = require("codeboomer.review")
local sidebar = require("codeboomer.sidebar")
local M = {}
local range_ns = vim.api.nvim_create_namespace("codeboomer-review-ranges")
local range_hl = "DiffAdd"
local remote = "origin"
local current = nil
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
local function under_worktree(path)
  local p = (path or "")
  return (current and (1 == p:find((current.worktree .. "/"), 1, true)))
end
local function worktree_path(id)
  local root = git["repo-root"]()
  if root then
    return (vim.fn.stdpath("data") .. "/codeboomer-review/" .. vim.fs.basename(root) .. "-" .. id)
  else
    return nil
  end
end
local function ensure_worktree(path, sha, k)
  if vim.uv.fs_stat(path) then
    local function _6_(_)
      local function _7_(_0)
        local function _8_(_1)
          return k()
        end
        return run({"git", "-C", path, "clean", "-fd"}, _8_)
      end
      return run({"git", "-C", path, "reset", "--hard", sha}, _7_)
    end
    return run({"git", "-C", path, "checkout", "--detach", sha}, _6_)
  else
    vim.fn.mkdir((vim.fs.dirname(path) or "."), "p")
    local function _9_(_)
      local function _10_(_0)
        return k()
      end
      return run({"git", "worktree", "add", "--detach", path, sha}, _10_)
    end
    return run({"git", "worktree", "prune"}, _9_)
  end
end
local function parse_ranges(diff)
  local file = nil
  local out = {}
  for line in string.gmatch((diff or ""), "[^\n]+") do
    local header = string.match(line, "^%+%+%+ b/(.*)")
    if (header and (header ~= "/dev/null")) then
      file = header
    else
    end
    local c, d = string.match(line, "^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
    if (file and c) then
      local start = tonumber(c)
      local count
      local function _13_()
        if (not d or (d == "")) then
          return "1"
        else
          return d
        end
      end
      count = tonumber(_13_())
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
local function place_ranges(bufnr, path)
  if vim.api.nvim_buf_is_valid(bufnr) then
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, range_ns, 0, -1)
    for _, _16_ in ipairs((current.ranges[path] or {})) do
      local start = _16_[1]
      local last = _16_[2]
      for ln = start, math.min(last, line_count) do
        vim.api.nvim_buf_set_extmark(bufnr, range_ns, (ln - 1), 0, {line_hl_group = range_hl})
      end
    end
    return nil
  else
    return nil
  end
end
local function configure_code_buffer(bufnr)
  if (current and vim.api.nvim_buf_is_valid(bufnr)) then
    local path = vim.api.nvim_buf_get_name(bufnr)
    if under_worktree(path) then
      local bo = vim.bo[bufnr]
      local rel = path:sub((2 + #current.worktree))
      bo.modifiable = false
      bo.readonly = true
      return place_ranges(bufnr, rel)
    else
      return nil
    end
  else
    return nil
  end
end
local function gh_view(n, k)
  local function _20_(out)
    local ok, pr = pcall(vim.json.decode, out)
    if (ok and ("table" == type(pr)) and pr.number) then
      return k(pr)
    else
      return notify(("codeboomer: `gh pr view " .. tostring(n) .. "` gave nothing usable"), vim.log.levels.ERROR)
    end
  end
  return run({"gh", "pr", "view", tostring(n), "--json", "number,headRefName,baseRefName"}, _20_)
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
  local function _23_(selected)
    local pr = by_display[selected[1]]
    if pr then
      return k(pr)
    else
      return nil
    end
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a PR> ", actions = {default = _23_}})
end
local function pick_fetch_remote()
  local remotes = (git.remotes() or {})
  local pick = nil
  for _, r in ipairs(remotes) do
    if pick then break end
    if ((r.name == "origin") and string.find((r.url or ""), "github.com", 1, true)) then
      pick = r.name
    else
    end
  end
  for _, r in ipairs(remotes) do
    if pick then break end
    if string.find((r.url or ""), "github.com", 1, true) then
      pick = r.name
    else
    end
  end
  return pick
end
local function open_pr(pr)
  local fetch_remote = pick_fetch_remote()
  if not fetch_remote then
    return notify("codeboomer: no remote to fetch the PR from", vim.log.levels.ERROR)
  else
    local function _27_(_)
      local function _28_(head)
        local function _29_(_0)
          local function _30_(base)
            local function _31_(mb)
              return M["setup-review"]({["pr-number"] = pr.number, ["head-sha"] = vim.trim(head), ["base-sha"] = vim.trim(mb), branch = pr.headRefName})
            end
            return run({"git", "merge-base", vim.trim(base), vim.trim(head)}, _31_)
          end
          return run({"git", "rev-parse", "FETCH_HEAD"}, _30_)
        end
        return run({"git", "fetch", fetch_remote, pr.baseRefName}, _29_)
      end
      return run({"git", "rev-parse", "FETCH_HEAD"}, _28_)
    end
    return run({"git", "fetch", fetch_remote, ("pull/" .. pr.number .. "/head")}, _27_)
  end
end
local function stage_worktree(root, k)
  local index = (root .. "/.git/codeboomer-snapshot-index")
  local cmd = string.format("rm -f '%s' && GIT_INDEX_FILE='%s' git -C '%s' add -A && GIT_INDEX_FILE='%s' git -C '%s' write-tree", index, index, root, index, root)
  local function _33_(out)
    return k(vim.trim(out))
  end
  return run({"sh", "-c", cmd}, _33_)
end
local function snapshot_commit(root, head, k)
  local function _34_(tree)
    if (not tree or ("" == tree)) then
      return notify("codeboomer: could not snapshot the working tree", vim.log.levels.ERROR)
    else
      local function _35_(out)
        return k(vim.trim(out))
      end
      return run({"git", "-C", root, "commit-tree", tree, "-p", head, "-m", "codeboomer-snapshot"}, _35_)
    end
  end
  return stage_worktree(root, _34_)
end
local function load_ranges(k)
  local function _37_(out)
    current.ranges = parse_ranges(out)
    return k()
  end
  return run({"git", "-C", current.worktree, "diff", "--unified=0", (current["base-sha"] .. ".." .. current["head-sha"])}, _37_)
end
local function open_review_tab()
  vim.cmd("tabnew")
  sidebar["open-sticky"]()
  local ok = pcall(M.files)
  if not ok then
    return notify("codeboomer: review open \226\128\148 :Codeboomer ReviewFiles to jump", vim.log.levels.INFO)
  else
    return nil
  end
end
local function _39_()
  if not current then
    return notify("codeboomer: no review open \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
  else
    local paths = vim.tbl_keys(current.ranges)
    if (0 == #paths) then
      return notify("codeboomer: no changed files in this review", vim.log.levels.WARN)
    else
      table.sort(paths)
      local fzf = require("fzf-lua")
      local function _40_(selected)
        local path = selected[1]
        return vim.cmd({cmd = "edit", args = {(current.worktree .. "/" .. path)}})
      end
      return fzf.fzf_exec(paths, {prompt = "Pick a Changed File> ", actions = {default = _40_}})
    end
  end
end
M.files = _39_
local function _43_(opts)
  local path = worktree_path((opts["worktree-id"] or ("pr" .. (opts["pr-number"] or ""))))
  if not path then
    return notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
  else
    local function _44_()
      local copts = {["pr-number"] = opts["pr-number"], ["head-sha"] = opts["head-sha"], ["base-sha"] = opts["base-sha"], branch = opts.branch}
      local session
      if opts["pr-number"] then
        session = (review["session-for-pr"](opts["pr-number"]) or review["create-session"](copts))
      else
        session = review["create-session"](copts)
      end
      current = {["pr-number"] = opts["pr-number"], ["head-sha"] = opts["head-sha"], ["base-sha"] = opts["base-sha"], branch = opts.branch, worktree = path, ["session-id"] = session, ranges = {}}
      review["set-session"](session)
      return load_ranges(open_review_tab)
    end
    return ensure_worktree(path, opts["head-sha"], _44_)
  end
end
M["setup-review"] = _43_
local function _47_(_3fn)
  if not git["repo-root"]() then
    return notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
  else
    if _3fn then
      return gh_view(_3fn, open_pr)
    else
      local function _48_(out)
        local ok, prs = pcall(vim.json.decode, out)
        if (ok and ("table" == type(prs)) and (#prs > 0)) then
          return choose_pr(prs, open_pr)
        else
          return notify("codeboomer: no open PRs (or `gh` unavailable)", vim.log.levels.WARN)
        end
      end
      return run({"gh", "pr", "list", "--json", "number,title,headRefName"}, _48_)
    end
  end
end
M.open = _47_
local function _52_()
  local root = git["repo-root"]()
  local head = git["head-sha"]()
  if not (root and head) then
    return notify("codeboomer: not inside a git repository with commits", vim.log.levels.ERROR)
  else
    local function _53_(sha)
      return M["setup-review"]({["worktree-id"] = "worktree", ["head-sha"] = sha, ["base-sha"] = head, branch = git["branch-name"]()})
    end
    return snapshot_commit(root, head, _53_)
  end
end
M["review-worktree"] = _52_
local function _55_()
  return current
end
M.info = _55_
M["parse-ranges"] = parse_ranges
M["fetch-remote"] = pick_fetch_remote
vim.api.nvim_create_augroup("codeboomer-review-mode", {clear = true})
local function _56_()
  if current then
    return configure_code_buffer(0)
  else
    return nil
  end
end
vim.api.nvim_create_autocmd("BufEnter", {group = "codeboomer-review-mode", callback = _56_})
return M
