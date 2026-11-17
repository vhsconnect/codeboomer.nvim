-- [nfnl] fnl/codeboomer/launch-processes.fnl
vim = vim
local M = {}
local default_launch_processes = {{label = "terminal", argv = {vim.o.shell}}, {label = "pi", argv = {"pi"}}, {label = "claude", argv = {"claude"}}}
M.defaults = function()
  local tbl_26_ = {}
  local i_27_ = 0
  for _, p in ipairs(default_launch_processes) do
    local val_28_ = {label = p.label, argv = vim.list_slice(p.argv)}
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
    t_2_ = t_2_.launch_processes
  else
  end
  return t_2_
end
return M
