-- [nfnl] fnl/codeboomer/review-mode.fnl
vim = vim
local git = require("codeboomer.git")
local review = require("codeboomer.review")
local sidebar = require("codeboomer.sidebar")
local github = require("codeboomer.github")
local M = {}
local range_ns = vim.api.nvim_create_namespace("codeboomer-review-ranges")
local function range_hl(side)
  if (side == "old") then
    return "DiffDelete"
  else
    return "DiffAdd"
  end
end
local remote = "origin"
local current = nil
local function notify(msg, level)
  local function _2_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_2_)
end
local function run(argv, k)
  local function _3_(obj)
    local function _4_()
      if (obj.code == 0) then
        return k((obj.stdout or ""))
      else
        return notify(("codeboomer: `" .. table.concat(argv, " ") .. "` failed (exit " .. tostring(obj.code) .. ")\n" .. (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return vim.schedule(_4_)
  end
  return vim.system(argv, {text = true}, _3_)
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
    local function _7_(_)
      local function _8_(_0)
        local function _9_(_1)
          return k()
        end
        return run({"git", "-C", path, "clean", "-fd"}, _9_)
      end
      return run({"git", "-C", path, "reset", "--hard", sha}, _8_)
    end
    return run({"git", "-C", path, "checkout", "--detach", sha}, _7_)
  else
    vim.fn.mkdir((vim.fs.dirname(path) or "."), "p")
    local function _10_(_)
      local function _11_(_0)
        return k()
      end
      return run({"git", "worktree", "add", "--detach", path, sha}, _11_)
    end
    return run({"git", "worktree", "prune"}, _10_)
  end
end
local function parse_ranges(diff, _3fside)
  local base_side = (_3fside == "base")
  local header_re
  if base_side then
    header_re = "^--- a/(.*)"
  else
    header_re = "^%+%+%+ b/(.*)"
  end
  local hunk_re
  if base_side then
    hunk_re = "^@@ %-(%d+),?(%d*) %+%d+,?%d* @@"
  else
    hunk_re = "^@@ %-%d+,?%d* %+(%d+),?(%d*) @@"
  end
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
      local function _16_()
        if (not d or (d == "")) then
          return "1"
        else
          return d
        end
      end
      count = tonumber(_16_())
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
    local hl = range_hl(current.side)
    vim.api.nvim_buf_clear_namespace(bufnr, range_ns, 0, -1)
    for _, _19_ in ipairs((current.ranges[path] or {})) do
      local start = _19_[1]
      local last = _19_[2]
      for ln = start, math.min(last, line_count) do
        vim.api.nvim_buf_set_extmark(bufnr, range_ns, (ln - 1), 0, {line_hl_group = hl})
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
      vim.b[bufnr]["codeboomer_review_side"] = current.side
      sidebar["mark-buffer"](bufnr)
      return place_ranges(bufnr, rel)
    else
      return nil
    end
  else
    return nil
  end
end
local function reload_worktree_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if (vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) and under_worktree(vim.api.nvim_buf_get_name(bufnr))) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local wins = vim.fn.win_findbuf(bufnr)
      local gone = not vim.uv.fs_stat(name)
      if (not gone and (#wins > 0)) then
        for _0, w in ipairs(wins) do
          local view = vim.api.nvim_win_call(w, vim.fn.winsaveview)
          local function _23_()
            return vim.cmd("silent! edit!")
          end
          vim.api.nvim_win_call(w, _23_)
          local function _24_()
            return vim.fn.winrestview(view)
          end
          vim.api.nvim_win_call(w, _24_)
        end
      else
        if gone then
          local _25_
          if (current.side == "old") then
            _25_ = "old"
          else
            _25_ = "new"
          end
          notify(("codeboomer: " .. vim.fs.basename(name) .. " does not exist on the " .. _25_ .. " side"), vim.log.levels.INFO)
        else
        end
        vim.api.nvim_buf_delete(bufnr, {force = true})
      end
    else
    end
  end
  return nil
end
local function gh_view(n, k)
  local function _30_(out)
    local ok, pr = pcall(vim.json.decode, out)
    if (ok and ("table" == type(pr)) and pr.number) then
      return k(pr)
    else
      return notify(("codeboomer: `gh pr view " .. tostring(n) .. "` gave nothing usable"), vim.log.levels.ERROR)
    end
  end
  return run({"gh", "pr", "view", tostring(n), "--json", "number,headRefName,baseRefName"}, _30_)
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
  local function _33_(selected)
    local pr = by_display[selected[1]]
    if pr then
      return k(pr)
    else
      return nil
    end
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a PR> ", actions = {default = _33_}})
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
  local head_ref = ("refs/codeboomer/pr-" .. pr.number .. "-head")
  local base_ref = ("refs/codeboomer/pr-" .. pr.number .. "-base")
  if not fetch_remote then
    return notify("codeboomer: no remote to fetch the PR from", vim.log.levels.ERROR)
  else
    local function _37_(_)
      local function _38_(_0)
        local function _39_(head)
          local function _40_(base)
            local function _41_(mb)
              local function _42_()
                return github["pull-comments"](pr.number)
              end
              return M["setup-review"]({["pr-number"] = pr.number, ["head-sha"] = vim.trim(head), ["base-sha"] = vim.trim(mb), branch = pr.headRefName}, _42_)
            end
            return run({"git", "merge-base", vim.trim(base), vim.trim(head)}, _41_)
          end
          return run({"git", "rev-parse", base_ref}, _40_)
        end
        return run({"git", "rev-parse", head_ref}, _39_)
      end
      return run({"git", "fetch", fetch_remote, string.format("+%s:%s", pr.baseRefName, base_ref)}, _38_)
    end
    return run({"git", "fetch", fetch_remote, string.format("+pull/%d/head:%s", pr.number, head_ref)}, _37_)
  end
end
local function stage_worktree(root, k)
  local index = (root .. "/.git/codeboomer-snapshot-index")
  local cmd = string.format("rm -f '%s' && GIT_INDEX_FILE='%s' git -C '%s' add -A && GIT_INDEX_FILE='%s' git -C '%s' write-tree", index, index, root, index, root)
  local function _44_(out)
    return k(vim.trim(out))
  end
  return run({"sh", "-c", cmd}, _44_)
end
local function snapshot_commit(root, head, k)
  local function _45_(tree)
    if (not tree or ("" == tree)) then
      return notify("codeboomer: could not snapshot the working tree", vim.log.levels.ERROR)
    else
      local function _46_(out)
        return k(vim.trim(out))
      end
      return run({"git", "-C", root, "commit-tree", tree, "-p", head, "-m", "codeboomer-snapshot"}, _46_)
    end
  end
  return stage_worktree(root, _45_)
end
local function load_ranges(k)
  local function _48_(out)
    current["head-ranges"] = parse_ranges(out)
    current["base-ranges"] = parse_ranges(out, "base")
    if (current.side == "old") then
      current.ranges = current["base-ranges"]
    else
      current.ranges = current["head-ranges"]
    end
    return k()
  end
  return run({"git", "-C", current.worktree, "diff", "--unified=0", (current["base-sha"] .. ".." .. current["head-sha"])}, _48_)
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
local function _51_()
  if not current then
    return notify("codeboomer: no review open \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
  else
    local paths = vim.tbl_keys(current.ranges)
    if (0 == #paths) then
      return notify("codeboomer: no changed files in this review", vim.log.levels.WARN)
    else
      table.sort(paths)
      local fzf = require("fzf-lua")
      local function _52_()
        if (current.side == "old") then
          return "old"
        else
          return "new"
        end
      end
      local function _53_(selected)
        local path = selected[1]
        return vim.cmd({cmd = "edit", args = {(current.worktree .. "/" .. path)}})
      end
      return fzf.fzf_exec(paths, {prompt = string.format("Pick a Changed File (%s side)> ", _52_()), actions = {default = _53_}})
    end
  end
end
M.files = _51_
local function _56_()
  if not current then
    return notify("codeboomer: no review open \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
  else
    local side
    if (current.side == "old") then
      side = "new"
    else
      side = "old"
    end
    local sha
    if (side == "old") then
      sha = current["base-sha"]
    else
      sha = current["head-sha"]
    end
    local function _59_(_)
      current.side = side
      if (side == "old") then
        current.ranges = current["base-ranges"]
      else
        current.ranges = current["head-ranges"]
      end
      reload_worktree_buffers()
      sidebar["reload-threads"]()
      local _61_
      if (side == "old") then
        _61_ = "old"
      else
        _61_ = "new"
      end
      return notify(("codeboomer: showing the " .. _61_ .. " code"), vim.log.levels.INFO)
    end
    return run({"git", "-C", current.worktree, "checkout", "--detach", sha}, _59_)
  end
end
M["toggle-side"] = _56_
local function _64_(opts, _3fdone)
  local path = worktree_path((opts["worktree-id"] or ("pr" .. (opts["pr-number"] or ""))))
  if not path then
    return notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
  else
    local function _65_()
      local copts = {["pr-number"] = opts["pr-number"], ["head-sha"] = opts["head-sha"], ["base-sha"] = opts["base-sha"], branch = opts.branch}
      local session
      if opts["pr-number"] then
        session = (review["session-for-pr"](opts["pr-number"]) or review["create-session"](copts))
      else
        session = review["create-session"](copts)
      end
      current = {["pr-number"] = opts["pr-number"], ["head-sha"] = opts["head-sha"], ["base-sha"] = opts["base-sha"], branch = opts.branch, worktree = path, ["session-id"] = session, side = "new", ["head-ranges"] = {}, ["base-ranges"] = {}, ranges = {}}
      review["set-session"](session)
      local function _67_()
        open_review_tab()
        if _3fdone then
          return _3fdone()
        else
          return nil
        end
      end
      return load_ranges(_67_)
    end
    return ensure_worktree(path, opts["head-sha"], _65_)
  end
end
M["setup-review"] = _64_
local function _70_(_3fn)
  if not git["repo-root"]() then
    return notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
  else
    if _3fn then
      return gh_view(_3fn, open_pr)
    else
      local function _71_(out)
        local ok, prs = pcall(vim.json.decode, out)
        if (ok and ("table" == type(prs)) and (#prs > 0)) then
          return choose_pr(prs, open_pr)
        else
          return notify("codeboomer: no open PRs (or `gh` unavailable)", vim.log.levels.WARN)
        end
      end
      return run({"gh", "pr", "list", "--json", "number,title,headRefName,baseRefName"}, _71_)
    end
  end
end
M.open = _70_
local function _75_()
  local root = git["repo-root"]()
  local head = git["head-sha"]()
  if not (root and head) then
    return notify("codeboomer: not inside a git repository with commits", vim.log.levels.ERROR)
  else
    local function _76_(sha)
      return M["setup-review"]({["worktree-id"] = "worktree", ["head-sha"] = sha, ["base-sha"] = head, branch = git["branch-name"]()})
    end
    return snapshot_commit(root, head, _76_)
  end
end
M["review-worktree"] = _75_
local function _78_()
  local _79_
  if current then
    _79_ = current["head-ranges"]
  else
    _79_ = nil
  end
  return github["post-threads"]({ranges = _79_})
end
M.post = _78_
local function _81_()
  local sid = review["current-session-id"]()
  local session
  if sid then
    session = review["session-by-id"](sid)
  else
    session = nil
  end
  if (session and session.pr_number) then
    return github["pull-comments"](session.pr_number)
  else
    return notify("codeboomer: the chosen session is not a PR review", vim.log.levels.WARN)
  end
end
M.pull = _81_
local function _84_()
  return current
end
M.info = _84_
M["parse-ranges"] = parse_ranges
M["fetch-remote"] = pick_fetch_remote
vim.api.nvim_create_augroup("codeboomer-review-mode", {clear = true})
local function _85_()
  if current then
    return configure_code_buffer(0)
  else
    return nil
  end
end
vim.api.nvim_create_autocmd("BufEnter", {group = "codeboomer-review-mode", callback = _85_})
return M
