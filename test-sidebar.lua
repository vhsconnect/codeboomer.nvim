-- headless smoke test for the review-comments sidebar pane
-- run: nvim --headless -u NONE --cmd "set rtp^=..." -c "luafile test-sidebar.lua"
-- (cwd = repo root; read-only DB use)
--
-- headless -c scripts never process input or fire deferred CursorMoved,
-- so each cursor move is followed by an explicit `doautocmd CursorMoved`
-- — the same callback path real cursor movement takes.
local api = vim.api
local fails = 0

local function check(desc, cond)
  if cond then
    print(("PASS  " .. desc))
  else
    fails = fails + 1
    print(("FAIL  " .. desc))
  end
end

local function move(win, line)
  api.nvim_win_set_cursor(win, { line, 0 })
  vim.cmd("doautocmd CursorMoved")
end

-- target file: real threads exist at lines 3 and 57-69 in the dev DB
vim.cmd("edit fnl/codeboomer/init.fnl")
local code_win = api.nvim_get_current_win()

local sidebar = require("codeboomer.sidebar")
sidebar.toggle()

local pane_buf, pane_win
for _, w in ipairs(api.nvim_list_wins()) do
  local b = api.nvim_win_get_buf(w)
  if api.nvim_buf_get_name(b) == "codeboomer://review-comments" then
    pane_buf, pane_win = b, w
  end
end
check("pane window opened", pane_win ~= nil)
check("cursor stayed in code window", api.nvim_get_current_win() == code_win)
check("pane is nofile + unmodifiable", vim.bo[pane_buf].buftype == "nofile"
  and vim.bo[pane_buf].modifiable == false)

local function pane_lines()
  return api.nvim_buf_get_lines(pane_buf, 0, -1, false)
end

-- gutter marks: extmark signs live in the pane namespace on the code
-- buffer — rows are 0-based here
local ns = api.nvim_create_namespace("codeboomer-review-pane")
local function sign_rows(buf)
  local rows = {}
  for _, m in ipairs(api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})) do
    rows[#rows + 1] = m[2] + 1
  end
  table.sort(rows)
  return rows
end

local code_buf = api.nvim_win_get_buf(code_win)
-- thread #1 sits at 3-3, thread #2 was widened to 1-69 by the test
-- wrapper so the ranges overlap: lines 1-2 carry one mark, line 3 two
local expected = {}
for l = 1, 69 do expected[#expected + 1] = l end
local marks = api.nvim_buf_get_extmarks(code_buf, ns, 0, -1, { details = true })
check("one mark per commented line", #marks == 70)
check("signcolumn widened to auto:2", vim.wo[code_win].signcolumn == "auto:2")
local three = {}
for _, m in ipairs(marks) do
  if m[2] + 1 == 3 then three[#three + 1] = m end
end
check("overlap line 3 carries two consecutive symbols", #three == 2
  and three[1][4].sign_text == "✎ " and three[2][4].sign_text == "✎ ")
check("overlap colors differ (theme groups)",
  three[1][4].sign_hl_group ~= three[2][4].sign_hl_group)
check("earlier thread wins the left slot",
  three[1][4].priority > three[2][4].priority)

-- a wiped buffer keeps a single empty line
local function pane_blank()
  local lines = pane_lines()
  return #lines == 1 and lines[1] == ""
end

-- cursor on line 100: outside every (widened) range -> blank pane
move(code_win, 100)
check("line 100 -> blank pane", pane_blank())

-- cursor on line 3: touches BOTH overlapping threads -> both blocks
-- separated by a rule line
move(code_win, 3)
local both = pane_lines()
local has_rule = false
for _, l in ipairs(both) do
  local stripped = l:gsub("─", "")
  if stripped == "" and #l > 0 then has_rule = true end
end
check("line 3 -> pane shows both threads", not pane_blank())
check("blocks separated by a rule line", has_rule and #both > 3)
print("      pane: " .. table.concat(both, " / "))

-- cursor on line 10: only thread #2 covers it -> single block, no rule
move(code_win, 10)
local single = pane_lines()
local single_rule = false
for _, l in ipairs(single) do
  local stripped = l:gsub("─", "")
  if stripped == "" and #l > 0 then single_rule = true end
end
check("line 10 -> single thread, no separator", (not single_rule) and not pane_blank())

-- cursor on line 200: outside again -> text disappears
move(code_win, 200)
check("line 200 -> pane blank again", pane_blank())

-- toggle off
sidebar.toggle()
check("toggle closed the pane", pane_win == nil or not api.nvim_win_is_valid(pane_win))
check("gutter marks cleared on close", #sign_rows(code_buf) == 0)
check("augroup cleared",
  not pcall(function() return api.nvim_get_autocmds({ group = "codeboomer-review-pane" }) end)
  or #(api.nvim_get_autocmds({ group = "codeboomer-review-pane" }) or {}) == 0)

-- toggle back on after close still works
sidebar.toggle()
local reopened = false
for _, w in ipairs(api.nvim_list_wins()) do
  local b = api.nvim_win_get_buf(w)
  if api.nvim_buf_get_name(b) == "codeboomer://review-comments" then
    reopened = true
  end
end
check("pane reopens", reopened)

print(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
os.exit(fails == 0 and 0 or 1, true)
