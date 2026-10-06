-- [nfnl] fnl/codeboomer/picker.fnl
vim = vim
local M = {}
M.choose = function(prompt, items, display, k, _3ffzf_opts)
  local fzf = require("fzf-lua")
  local by_display = {}
  local lines
  do
    local tbl_26_ = {}
    local i_27_ = 0
    for _, item in ipairs(items) do
      local val_28_
      do
        local d = display(item)
        by_display[d] = item
        val_28_ = d
      end
      if (nil ~= val_28_) then
        i_27_ = (i_27_ + 1)
        tbl_26_[i_27_] = val_28_
      else
      end
    end
    lines = tbl_26_
  end
  local on_pick
  local function _2_(selected)
    local item = by_display[selected[1]]
    if item then
      return k(item)
    else
      return nil
    end
  end
  on_pick = _2_
  return fzf.fzf_exec(lines, vim.tbl_extend("force", (_3ffzf_opts or {}), {prompt = prompt, actions = {default = on_pick}}))
end
return M
