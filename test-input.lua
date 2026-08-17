-- test-input.lua — run: nvim -u dev.lua -l test-input.lua
local input = require("varubrev.input")

local submitted, cancelled = nil, nil

-- 1) submit: open, type two lines, press <CR> in the float
local win1 = input.open({
  title = " test ",
  on_submit = function(lines) submitted = lines end,
  on_cancel = function() cancelled = 1 end,
})
local buf1 = vim.api.nvim_win_get_buf(win1)
vim.api.nvim_buf_set_lines(buf1, 0, -1, false, { "echo hello", "echo world" })
vim.api.nvim_win_call(win1, function() vim.fn.feedkeys("\\<CR>", "x") end)
assert(vim.deep_equal(submitted, { "echo hello", "echo world" }), "submit got: " .. vim.inspect(submitted))
assert(cancelled == nil, "cancel must NOT fire on submit")
print("1) submit: OK — got", #submitted, "lines")

-- 2) cancel via <Esc>
local win2 = input.open({
  on_submit = function() submitted = "SHOULD NOT HAPPEN" end,
  on_cancel = function() cancelled = 2 end,
})
local buf2 = vim.api.nvim_win_get_buf(win2)
vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "typed stuff" })
vim.api.nvim_win_call(win2, function() vim.fn.feedkeys("\\<Esc>", "x") end)
assert(cancelled == 2, "cancel must fire on Esc")
assert(submitted == nil, "submit must NOT fire on cancel")
print("2) Esc cancel: OK — nothing submitted")

-- 3) cancel via closing the window directly (:q, <C-w>c path -> WinClosed)
local win3 = input.open({
  on_submit = function() submitted = "NOPE" end,
  on_cancel = function() cancelled = 3 end,
})
vim.api.nvim_win_close(win3, true)
assert(cancelled == 3, "cancel must fire on external close")
assert(submitted == nil)
print("3) external close: OK — counts as cancel")

-- 4) buffer/window hygiene: nothing left floating around
local wins = vim.api.nvim_list_wins()
print("4) windows open at end:", #wins)
print("ALL PASS")
