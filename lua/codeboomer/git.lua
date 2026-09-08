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
M["repo-root"] = function()
  return vim.fs.root(0, ".git")
end
M["branch-name"] = function()
  local root = M["repo-root"]()
  if root then
    return run(root, "rev-parse", "--abbrev-ref", "HEAD")
  else
    return nil
  end
end
M["head-sha"] = function()
  local root = M["repo-root"]()
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
