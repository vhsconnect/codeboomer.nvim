-- [nfnl] fnl/codeboomer/directives.fnl
vim = vim
local M = {}
local pushback_reasons = {"introducing bugs", "impacting readability", "impacting preformance heavily", "introducing security vulenerabilities", "result in data loss/inconsistency", "contradict original instruction"}
local pushback_clause = ("unless a comment merits pushback. Valid pushback reasons include " .. table.concat(pushback_reasons, ", "))
local default_directives = {{label = "Review - converse only", text = "Review my comments. Address each point and give me feedback. Do not make any code changes."}, {label = "Review - converse + change", text = ("Review my comments. Address each point in its thread, then make the changes " .. pushback_clause)}, {label = "Review - change", text = ("Make the changes my comments ask for directly, without discussing them first, " .. pushback_clause)}}
M.defaults = function()
  local tbl_26_ = {}
  local i_27_ = 0
  for _, d in ipairs(default_directives) do
    local val_28_ = {label = d.label, text = d.text}
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
    t_2_ = t_2_.directives
  else
  end
  return t_2_
end
M.get = function(label)
  local result = nil
  for _, d in ipairs((M.list() or {})) do
    if (d.label == label) then
      result = d.text
    else
      result = result
    end
  end
  return result
end
return M
