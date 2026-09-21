-- [nfnl] fnl/codeboomer/review-mode.fnl
vim = vim
local git = require("codeboomer.git")
local review = require("codeboomer.review")
local sidebar = require("codeboomer.sidebar")
local github = require("codeboomer.github")
local input = require("codeboomer.input")
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
local function _2_(path)
  if (current and (review["current-session-id"]() == current["session-id"])) then
    return (current.worktree .. "/" .. path)
  else
    return nil
  end
end
sidebar["set-open-path"](_2_)
local function _4_()
  if current then
    return {["session-id"] = current["session-id"], ["head-sha"] = current["head-sha"], ["head-ranges"] = current["head-ranges"]}
  else
    return nil
  end
end
sidebar["set-promote-context"](_4_)
local function notify(msg, level)
  local function _6_()
    return vim.notify(msg, level)
  end
  return vim.schedule(_6_)
end
local function run(argv, k)
  local function _7_(obj)
    local function _8_()
      if (obj.code == 0) then
        return k((obj.stdout or ""))
      else
        return notify(("codeboomer: `" .. table.concat(argv, " ") .. "` failed (exit " .. tostring(obj.code) .. ")\n" .. (obj.stderr or "")), vim.log.levels.ERROR)
      end
    end
    return vim.schedule(_8_)
  end
  return vim.system(argv, {text = true}, _7_)
end
local function under_worktree(path)
  local p = (path or "")
  return (current and (1 == p:find((current.worktree .. "/"), 1, true)))
end
local function normalize_dir(_3fdir)
  return string.gsub(string.gsub((_3fdir or ""), "^/+", ""), "/+$", "")
end
local function worktree_leaf(root, id)
  return (vim.fs.basename(root) .. "-" .. id)
end
local function discover_worktree(leaf, k)
  local function _10_(out)
    local found = nil
    for line in string.gmatch(out, "[^\n]+") do
      local p = line:match("^worktree%s+(.+)")
      if (p and (vim.fs.basename(p) == leaf)) then
        found = p
      else
      end
    end
    return k(found)
  end
  return run({"git", "worktree", "list", "--porcelain"}, _10_)
end
local function relocate_worktree(old, path, k)
  if (old and (old ~= path)) then
    local function _12_(_)
      return k()
    end
    return run({"git", "worktree", "remove", "--force", old}, _12_)
  else
    return k()
  end
end
local function ensure_worktree(path, sha, k)
  if vim.uv.fs_stat(path) then
    local function _14_(_)
      local function _15_(_0)
        local function _16_(_1)
          return k()
        end
        return run({"git", "-C", path, "clean", "-fd"}, _16_)
      end
      return run({"git", "-C", path, "reset", "--hard", sha}, _15_)
    end
    return run({"git", "-C", path, "checkout", "--detach", sha}, _14_)
  else
    vim.fn.mkdir((vim.fs.dirname(path) or "."), "p")
    local function _17_(_)
      local function _18_(_0)
        return k()
      end
      return run({"git", "worktree", "add", "--detach", path, sha}, _18_)
    end
    return run({"git", "worktree", "prune"}, _17_)
  end
end
local function pick_worktree_path(id, k)
  local root = git["repo-root"]()
  if not root then
    notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
    return k(nil)
  else
    local leaf = worktree_leaf(root, id)
    local function _20_(found)
      local default = (found or (vim.fs.dirname(root) .. "/" .. leaf))
      local function _21_(lines)
        local path = vim.trim((lines[1] or ""))
        if (path == "") then
          notify("codeboomer: worktree path required", vim.log.levels.WARN)
          return k(nil)
        else
          local function _22_()
            return k(path)
          end
          return relocate_worktree(found, path, _22_)
        end
      end
      return input.open({title = " Review worktree path> ", prefill = default, ["submit-on-enter"] = true, ["on-submit"] = _21_})
    end
    return discover_worktree(leaf, _20_)
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
      local function _28_()
        if (not d or (d == "")) then
          return "1"
        else
          return d
        end
      end
      count = tonumber(_28_())
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
    for _, _31_ in ipairs((current.ranges[path] or {})) do
      local start = _31_[1]
      local last = _31_[2]
      for ln = start, math.min(last, line_count) do
        vim.api.nvim_buf_set_extmark(bufnr, range_ns, (ln - 1), 0, {line_hl_group = hl})
      end
    end
    return nil
  else
    return nil
  end
end
local function step_in_file(ranges, line, dir)
  if (dir == "prev") then
    local found = nil
    for _, r in ipairs((ranges or {})) do
      if (r[1] < line) then
        found = r
      else
        found = found
      end
    end
    return found
  else
    local found = nil
    for _, r in ipairs((ranges or {})) do
      local or_34_ = found
      if not or_34_ then
        if (r[1] > line) then
          or_34_ = r
        else
          or_34_ = nil
        end
      end
      found = or_34_
    end
    return found
  end
end
local function side_paths()
  local paths = vim.tbl_keys(current.ranges)
  table.sort(paths)
  return paths
end
local function goto_hunk(rel, path, start)
  if (rel ~= path) then
    vim.cmd({cmd = "edit", args = {(current.worktree .. "/" .. path)}})
  else
  end
  vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), {start, 0})
  return vim.cmd("normal! zz")
end
local function jump_hunk(dir)
  local name = vim.api.nvim_buf_get_name(0)
  local line
  do
    local t_38_ = vim.api.nvim_win_get_cursor(0)
    if (nil ~= t_38_) then
      t_38_ = t_38_[1]
    else
    end
    line = t_38_
  end
  if not current then
    return notify("codeboomer: no review open \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
  else
    local paths = side_paths()
    if (0 == #paths) then
      return notify("codeboomer: no changed files in this review", vim.log.levels.WARN)
    else
      local rel = name:sub((2 + #current.worktree))
      local around = step_in_file(current.ranges[rel], (line or 0), dir)
      local hop
      if around then
        hop = {rel, around[1]}
      else
        local len = #paths
        local idx = vim.fn.index(paths, rel)
        local pos
        if (idx == -1) then
          if (dir == "prev") then
            pos = len
          else
            pos = 1
          end
        else
          local _41_
          if (dir == "prev") then
            _41_ = -1
          else
            _41_ = 1
          end
          pos = (1 + ((idx + _41_) % len))
        end
        local target = paths[pos]
        local ranges = current.ranges[target]
        local r
        if (dir == "prev") then
          r = ranges[#ranges]
        else
          r = ranges[1]
        end
        hop = {target, r[1]}
      end
      return goto_hunk(rel, hop[1], hop[2])
    end
  end
end
local function _48_()
  return jump_hunk("next")
end
M["next-hunk"] = _48_
local function _49_()
  return jump_hunk("prev")
end
M["prev-hunk"] = _49_
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
      vim.keymap.set("n", "]a", M["next-hunk"], {buffer = bufnr, desc = "codeboomer: next review hunk"})
      vim.keymap.set("n", "[a", M["prev-hunk"], {buffer = bufnr, desc = "codeboomer: previous review hunk"})
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
          local function _52_()
            return vim.cmd("silent! edit!")
          end
          vim.api.nvim_win_call(w, _52_)
          local function _53_()
            return vim.fn.winrestview(view)
          end
          vim.api.nvim_win_call(w, _53_)
        end
      else
        if gone then
          local _54_
          if (current.side == "old") then
            _54_ = "old"
          else
            _54_ = "new"
          end
          notify(("codeboomer: " .. vim.fs.basename(name) .. " does not exist on the " .. _54_ .. " side"), vim.log.levels.INFO)
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
  local function _59_(out)
    local ok, pr = pcall(vim.json.decode, out)
    if (ok and ("table" == type(pr)) and pr.number) then
      return k(pr)
    else
      return notify(("codeboomer: `gh pr view " .. tostring(n) .. "` gave nothing usable"), vim.log.levels.ERROR)
    end
  end
  return run({"gh", "pr", "view", tostring(n), "--json", "number,headRefName,baseRefName"}, _59_)
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
  local function _62_(selected)
    local pr = by_display[selected[1]]
    if pr then
      return k(pr)
    else
      return nil
    end
  end
  return fzf.fzf_exec(lines, {prompt = "Pick a PR> ", actions = {default = _62_}})
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
    local function _66_(_)
      local function _67_(_0)
        local function _68_(head)
          local function _69_(base)
            local function _70_(mb)
              local function _71_()
                return github["pull-comments"](pr.number)
              end
              return M["setup-review"]({["pr-number"] = pr.number, ["head-sha"] = vim.trim(head), ["base-sha"] = vim.trim(mb), branch = pr.headRefName}, _71_)
            end
            return run({"git", "merge-base", vim.trim(base), vim.trim(head)}, _70_)
          end
          return run({"git", "rev-parse", base_ref}, _69_)
        end
        return run({"git", "rev-parse", head_ref}, _68_)
      end
      return run({"git", "fetch", fetch_remote, string.format("+%s:%s", pr.baseRefName, base_ref)}, _67_)
    end
    return run({"git", "fetch", fetch_remote, string.format("+pull/%d/head:%s", pr.number, head_ref)}, _66_)
  end
end
local function stage_worktree(root, head, _3fdir, k)
  local index = (root .. "/.git/codeboomer-snapshot-index")
  local dir = normalize_dir(_3fdir)
  local cmd
  local _73_
  if ("" == dir) then
    _73_ = ""
  else
    _73_ = string.format(" -- '%s'", dir)
  end
  cmd = string.format("rm -f '%s' && GIT_INDEX_FILE='%s' git -C '%s' read-tree %s && GIT_INDEX_FILE='%s' git -C '%s' add -A%s && GIT_INDEX_FILE='%s' git -C '%s' write-tree", index, index, root, head, index, root, _73_, index, root)
  local function _75_(out)
    return k(vim.trim(out))
  end
  return run({"sh", "-c", cmd}, _75_)
end
local function git_tree(root, sha)
  local out = vim.fn.system({"git", "-C", root, "rev-parse", (sha .. "^{tree}")})
  if (vim.v.shell_error == 0) then
    return vim.trim(out)
  else
    return nil
  end
end
local function snapshot_commit(root, head, _3fdir, k)
  local dir = normalize_dir(_3fdir)
  local function _77_(tree)
    if (not tree or ("" == tree)) then
      return notify("codeboomer: could not snapshot the working tree", vim.log.levels.ERROR)
    else
      if (("" ~= dir) and (tree == git_tree(root, head))) then
        return notify(("codeboomer: no uncommitted changes under " .. dir), vim.log.levels.WARN)
      else
        local function _78_(out)
          return k(vim.trim(out))
        end
        return run({"git", "-C", root, "commit-tree", tree, "-p", head, "-m", "codeboomer-snapshot"}, _78_)
      end
    end
  end
  return stage_worktree(root, head, dir, _77_)
end
local function load_ranges(k)
  local function _81_(out)
    current["head-ranges"] = parse_ranges(out)
    current["base-ranges"] = parse_ranges(out, "base")
    if (current.side == "old") then
      current.ranges = current["base-ranges"]
    else
      current.ranges = current["head-ranges"]
    end
    return k()
  end
  return run({"git", "-C", current.worktree, "diff", "--unified=0", (current["base-sha"] .. ".." .. current["head-sha"])}, _81_)
end
local function open_review_tab()
  vim.cmd("tabnew")
  sidebar.open()
  local ok = pcall(M.files)
  if not ok then
    return notify("codeboomer: review open \226\128\148 :Codeboomer ReviewFiles to jump", vim.log.levels.INFO)
  else
    return nil
  end
end
local qf_title = "codeboomer review"
local function qf_item(path, ranges)
  local groups
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, _84_ in ipairs(ranges) do
      local start = _84_[1]
      local last = _84_[2]
      local val_28_
      if (start == last) then
        val_28_ = ("L" .. start)
      else
        val_28_ = ("L" .. start .. "-" .. last)
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    groups = tbl_26_
  end
  local shown = vim.list_slice(groups, 1, 5)
  local extra
  if (#groups > 5) then
    extra = (", +" .. tostring((#groups - 5)) .. " more")
  else
    extra = nil
  end
  local _89_
  do
    local t_88_ = ranges
    if (nil ~= t_88_) then
      t_88_ = t_88_[1]
    else
    end
    if (nil ~= t_88_) then
      t_88_ = t_88_[1]
    else
    end
    _89_ = t_88_
  end
  return {filename = (current.worktree .. "/" .. path), lnum = _89_, text = (table.concat(shown, ", ") .. (extra or ""))}
end
local function scoped_paths(_3fdir)
  local trimmed = normalize_dir(_3fdir)
  if ("" == trimmed) then
    return vim.tbl_keys(current.ranges)
  else
    local tbl_26_ = {}
    local i_27_ = 0
    for _, path in ipairs(vim.tbl_keys(current.ranges)) do
      local val_28_
      if ((path == trimmed) or (1 == path:find((trimmed .. "/"), 1, true))) then
        val_28_ = path
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
end
local function set_qf()
  local paths = scoped_paths(current["qf-dir"])
  table.sort(paths)
  local _95_
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, p in ipairs(paths) do
      local val_28_ = qf_item(p, current.ranges[p])
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    _95_ = tbl_26_
  end
  local _97_
  if (current.side == "old") then
    _97_ = "old"
  else
    _97_ = "new"
  end
  local _99_
  if ("" == (current["qf-dir"] or "")) then
    _99_ = ""
  else
    _99_ = (" \226\128\148 " .. current["qf-dir"])
  end
  return vim.fn.setqflist({}, "r", {items = _95_, title = (qf_title .. " (" .. _97_ .. " side)" .. _99_)})
end
local function refresh_qf()
  local qf = vim.fn.getqflist({title = 1, winid = 1})
  local title = (qf.title or "")
  if (((qf.winid or 0) > 0) and (1 == title:find(qf_title, 1, true))) then
    return set_qf()
  else
    return nil
  end
end
local function _102_(_3fdir)
  if not current then
    return notify("codeboomer: no review open \226\128\148 :Codeboomer Review first", vim.log.levels.WARN)
  else
    local paths
    do
      current["qf-dir"] = (_3fdir or "")
      paths = scoped_paths(current["qf-dir"])
    end
    if (0 == #paths) then
      local _103_
      if ("" == current["qf-dir"]) then
        _103_ = "codeboomer: no changed files in this review"
      else
        _103_ = ("codeboomer: no changed files under " .. current["qf-dir"])
      end
      return notify(_103_, vim.log.levels.WARN)
    else
      set_qf()
      return vim.cmd({cmd = "copen", count = math.min(12, #paths)})
    end
  end
end
M.files = _102_
local function _107_()
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
    local function _110_(_)
      current.side = side
      if (side == "old") then
        current.ranges = current["base-ranges"]
      else
        current.ranges = current["head-ranges"]
      end
      reload_worktree_buffers()
      sidebar["reload-threads"]()
      refresh_qf()
      local _112_
      if (side == "old") then
        _112_ = "old"
      else
        _112_ = "new"
      end
      return notify(("codeboomer: showing the " .. _112_ .. " code"), vim.log.levels.INFO)
    end
    return run({"git", "-C", current.worktree, "checkout", "--detach", sha}, _110_)
  end
end
M["toggle-side"] = _107_
local function _115_(opts, _3fdone)
  local function _116_(path)
    if path then
      local function _117_()
        local copts = {["pr-number"] = opts["pr-number"], ["head-sha"] = opts["head-sha"], ["base-sha"] = opts["base-sha"], branch = opts.branch}
        local session
        if opts["pr-number"] then
          session = (review["session-for-pr"](opts["pr-number"]) or review["create-session"](copts))
        else
          session = review["create-session"](copts)
        end
        current = {["pr-number"] = opts["pr-number"], ["head-sha"] = opts["head-sha"], ["base-sha"] = opts["base-sha"], branch = opts.branch, worktree = path, ["session-id"] = session, side = "new", ["qf-dir"] = "", ["head-ranges"] = {}, ["base-ranges"] = {}, ranges = {}}
        review["set-session"](session)
        local function _119_()
          open_review_tab()
          if _3fdone then
            return _3fdone()
          else
            return nil
          end
        end
        return load_ranges(_119_)
      end
      return ensure_worktree(path, opts["head-sha"], _117_)
    else
      return nil
    end
  end
  return pick_worktree_path((opts["worktree-id"] or ("pr" .. (opts["pr-number"] or ""))), _116_)
end
M["setup-review"] = _115_
local function _122_(_3fn)
  if not git["repo-root"]() then
    return notify("codeboomer: not inside a git repository", vim.log.levels.ERROR)
  else
    if _3fn then
      return gh_view(_3fn, open_pr)
    else
      local function _123_(out)
        local ok, prs = pcall(vim.json.decode, out)
        if (ok and ("table" == type(prs)) and (#prs > 0)) then
          return choose_pr(prs, open_pr)
        else
          return notify("codeboomer: no open PRs (or `gh` unavailable)", vim.log.levels.WARN)
        end
      end
      return run({"gh", "pr", "list", "--json", "number,title,headRefName,baseRefName"}, _123_)
    end
  end
end
M.open = _122_
local function _127_(_3fdir)
  local root = git["repo-root"]()
  local head = git["head-sha"]()
  if not (root and head) then
    return notify("codeboomer: not inside a git repository with commits", vim.log.levels.ERROR)
  else
    local function _128_(sha)
      return M["setup-review"]({["worktree-id"] = "worktree", ["head-sha"] = sha, ["base-sha"] = head, branch = git["branch-name"]()})
    end
    return snapshot_commit(root, head, _3fdir, _128_)
  end
end
M["review-worktree"] = _127_
local function _130_()
  local _131_
  if current then
    _131_ = current["head-ranges"]
  else
    _131_ = nil
  end
  return github["post-threads"]({ranges = _131_})
end
M.post = _130_
local function _133_()
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
M.pull = _133_
local function _136_()
  return current
end
M.info = _136_
M["parse-ranges"] = parse_ranges
M["fetch-remote"] = pick_fetch_remote
vim.api.nvim_create_augroup("codeboomer-review-mode", {clear = true})
local function _137_()
  if current then
    return configure_code_buffer(0)
  else
    return nil
  end
end
vim.api.nvim_create_autocmd("BufEnter", {group = "codeboomer-review-mode", callback = _137_})
return M
