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
M["repo-root"] = function(_3fpath)
  return vim.fs.root((_3fpath or 0), ".git")
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
