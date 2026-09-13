-- [nfnl] fnl/codeboomer/git.fnl
vim = vim
local M = {}
local function run(root, ...)
  local out = vim.fn.system(vim.list_extend({"git", "-C", root}, {...}))
  if (vim.v.shell_error == 0) then
    local trimmed = out:gsub("\n+$", "")
    return trimmed
  else
    return nil
  end
end
local function buffer_root(_3fpath)
  return vim.fs.root((_3fpath or 0), ".git")
end
local function main_of(root)
  local gitfile = (root .. "/.git")
  local stat = vim.uv.fs_stat(gitfile)
  if (stat and (stat.type == "file")) then
    local gitdir
    local _3_
    do
      local t_2_ = vim.fn.readfile(gitfile)
      if (nil ~= t_2_) then
        t_2_ = t_2_[1]
      else
      end
      _3_ = t_2_
    end
    gitdir = string.match((_3_ or ""), "^gitdir:%s*(.+)")
    local wt_meta
    if gitdir then
      wt_meta = vim.fs.dirname(gitdir)
    else
      wt_meta = nil
    end
    local main_git
    if (wt_meta and ("worktrees" == vim.fs.basename(wt_meta))) then
      main_git = vim.fs.dirname(wt_meta)
    else
      main_git = nil
    end
    local main
    if main_git then
      main = vim.fs.dirname(main_git)
    else
      main = nil
    end
    return (main or root)
  else
    return root
  end
end
M["repo-root"] = function(_3fpath)
  local root = buffer_root(_3fpath)
  if root then
    return main_of(root)
  else
    return nil
  end
end
M["rel-path"] = function(_3fpath)
  local p = (_3fpath or vim.api.nvim_buf_get_name(0))
  local root = buffer_root(p)
  if (root and (1 == p:find((root .. "/"), 1, true))) then
    return p:sub((2 + #root))
  else
    return p
  end
end
M.remotes = function()
  local root = M["repo-root"]()
  if root then
    local out = run(root, "remote", "-v")
    local tbl_26_ = {}
    local i_27_ = 0
    for line in string.gmatch((out or ""), "[^\n]+") do
      local val_28_
      do
        local name, url, kind = string.match(line, "(%S+)%s+(%S+)%s+%((%a+)%)")
        if (kind == "fetch") then
          val_28_ = {name = name, url = url}
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
  else
    return nil
  end
end
M["branch-name"] = function()
  local root = M["repo-root"]()
  if root then
    return run(root, "rev-parse", "--abbrev-ref", "HEAD")
  else
    return nil
  end
end
M["head-sha"] = function(_3fpath)
  local root = buffer_root(_3fpath)
  if root then
    return run(root, "rev-parse", "HEAD")
  else
    return nil
  end
end
M["user-email"] = function()
  local root = M["repo-root"]()
  if root then
    return run(root, "config", "user.email")
  else
    return nil
  end
end
M["user-name"] = function()
  local root = M["repo-root"]()
  if root then
    return run(root, "config", "user.name")
  else
    return nil
  end
end
return M
