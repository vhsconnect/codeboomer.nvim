-- [nfnl] fnl/codeboomer/one-offs.fnl
vim = vim
local M = {}
local default_one_offs = {{label = "claude-code (haiku)", argv = {"claude-code", "--model", "haiku", "--output-format", "json", "--permission-mode", "acceptEdits", "-p"}}}
M.defaults = function()
  local tbl_26_ = {}
  local i_27_ = 0
  for _, c in ipairs(default_one_offs) do
    local val_28_ = {label = c.label, argv = vim.list_slice(c.argv)}
    if (nil ~= val_28_) then
      i_27_ = (i_27_ + 1)
      tbl_26_[i_27_] = val_28_
    else
    end
  end
  return tbl_26_
end
M.list = function()
  local t_2_ = require("codeboomer.config")
  if (nil ~= t_2_) then
    t_2_ = t_2_.config
  else
  end
  if (nil ~= t_2_) then
    t_2_ = t_2_.prompting
  else
  end
  if (nil ~= t_2_) then
    t_2_ = t_2_.one_off_commands
  else
  end
  return t_2_
end
return M
