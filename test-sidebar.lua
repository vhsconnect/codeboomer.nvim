-- headless smoke test for the per-tab review-comments sidebar pane
-- run: nvim --headless -u NONE --cmd "set rtp^=..." -c "luafile test-sidebar.lua"
-- (cwd = repo root; the shell wrapper widens thread 2 to overlap thread 1
-- and restores it afterwards; DB reads only)
--
-- headless -c scripts never process input or fire deferred CursorMoved,
-- so cursor moves are followed by explicit `doautocmd` calls — the same
-- callback paths real interaction takes.
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

-- target file: thread #1 at 3-3, thread #2 widened to 1-69 by the wrapper
vim.cmd("edit fnl/codeboomer/init.fnl")
local code_win = api.nvim_get_current_win()
local tab1 = api.nvim_get_current_tabpage()

local sidebar = require("codeboomer.sidebar")
sidebar.toggle()

local function find_pane(tab)
  for _, w in ipairs(api.nvim_tabpage_list_wins(tab)) do
    local b = api.nvim_win_get_buf(w)
    if api.nvim_buf_get_name(b):find("^codeboomer://review%-comments") then
      return b, w
    end
  end
end
local pane_buf, pane_win = find_pane(tab1)
check("pane window opened", pane_win ~= nil)
check("cursor stayed in code window", api.nvim_get_current_win() == code_win)
check("pane is nofile + unmodifiable", vim.bo[pane_buf].buftype == "nofile"
  and vim.bo[pane_buf].modifiable == false)

local function pane_lines()
  return api.nvim_buf_get_lines(pane_buf, 0, -1, false)
end

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
local marks = api.nvim_buf_get_extmarks(code_buf, ns, 0, -1, { details = true })
-- expected mark count straight from the DB — the dev DB keeps growing
-- as the plugin gets used, so no hardcoded totals
local review = require("codeboomer.review")
local ok, sid = pcall(function() return review["active-session-id"]() end)
local threads = (ok and sid)
  and review["threads-for"](sid, api.nvim_buf_get_name(code_buf)) or {}
local expected_marks = 0
for _, t in ipairs(threads) do
  expected_marks = expected_marks + (t.line_end - t.line_start + 1)
end
-- DB threads covering a line — the dev DB grows as the plugin is used,
-- so coverage expectations must be computed, never hardcoded
local function covering(line)
  local n = 0
  for _, t in ipairs(threads) do
    if line >= t.line_start and line <= t.line_end then n = n + 1 end
  end
  return n
end
check(("one mark per commented line (%d)"):format(expected_marks), #marks == expected_marks)
check("signcolumn widened to auto:2", vim.wo[code_win].signcolumn == "auto:2")
local three = {}
for _, m in ipairs(marks) do
  if m[2] + 1 == 3 then three[#three + 1] = m end
end
check(("line 3 carries one symbol per covering thread (%d)"):format(covering(3)),
  #three == covering(3) and covering(3) >= 2)
local all_crayons = true
for _, m in ipairs(three) do
  if m[4].sign_text ~= "✎ " then all_crayons = false end
end
check("symbols are crayons", #three >= 2 and all_crayons)
check("overlap colors differ (theme groups)",
  #three >= 2 and three[1][4].sign_hl_group ~= three[2][4].sign_hl_group)
check("earlier thread wins the left slot",
  #three >= 2 and three[1][4].priority > three[2][4].priority)

-- a wiped buffer keeps a single empty line
local function pane_blank()
  local lines = pane_lines()
  return #lines == 1 and lines[1] == ""
end

local function has_rule(lines)
  for _, l in ipairs(lines) do
    local stripped = l:gsub("─", "")
    if stripped == "" and #l > 0 then return true end
  end
  return false
end

move(code_win, 100)
check("line 100 -> blank pane", pane_blank())

-- cursor on line 3: touches BOTH overlapping threads -> both blocks
move(code_win, 3)
local both = pane_lines()
check("line 3 -> pane shows both threads", not pane_blank())
check("blocks separated by a rule line", has_rule(both) and #both > 3)
print("      pane: " .. table.concat(both, " / "))

-- a line covered by exactly one thread must render a single block
local single = nil
for l = 12, 69 do
  if covering(l) == 1 then single = l break end
end
if single then
  move(code_win, single)
  check(("line %d -> single thread, no separator"):format(single),
    not has_rule(pane_lines()) and not pane_blank())
end

move(code_win, 200)
check("line 200 -> pane blank again", pane_blank())

-- ── per-tab behavior ──────────────────────────────────────────────
move(code_win, 3) -- leave tab 1 showing thread content
vim.cmd("tabnew")
vim.cmd("doautocmd TabEnter")
local tab2 = api.nvim_get_current_tabpage()
check("second tab spawned its own pane", tab2 ~= tab1 and find_pane(tab2) ~= nil)

-- a threadless file in tab 2 keeps its pane blank and tab 1's marks intact
vim.cmd("edit README.md")
vim.cmd("doautocmd BufEnter")
local pane2_buf = find_pane(tab2)
local l2 = api.nvim_buf_get_lines(pane2_buf, 0, -1, false)
check("tab 2 pane blank for threadless file", #l2 == 1 and l2[1] == "")
check("leaving a tab collapses its markers", #sign_rows(code_buf) == 0)

-- back to tab 1: its pane re-renders from the tab's active window
vim.cmd("tabnext")
vim.cmd("doautocmd TabEnter")
vim.cmd("doautocmd WinEnter")
check("tab 1 pane re-renders on return", not pane_blank())
check("markers re-placed on return", #sign_rows(code_buf) == expected_marks)

-- ── the same file driven from a second tab must not double marks ──
vim.cmd("tabnext 2")
vim.cmd("doautocmd TabEnter")
vim.cmd("edit fnl/codeboomer/init.fnl")
vim.cmd("doautocmd BufEnter")
local dup = api.nvim_buf_get_extmarks(code_buf, ns, 0, -1, {})
check("no duplicated marks for shared buffer", #dup == expected_marks)
local three2 = {}
for _, m in ipairs(dup) do
  if m[2] + 1 == 3 then three2[#three2 + 1] = m end
end
check("mark count per covering line unchanged after shared drive",
  #three2 == covering(3))

-- closing the active tab's pane collapses its markers; the buffer
-- keeps no residual set
local _, pane2_win = find_pane(api.nvim_get_current_tabpage())
api.nvim_win_close(pane2_win, true)
check("closing a tab's pane collapses its markers",
  #api.nvim_buf_get_extmarks(code_buf, ns, 0, -1, {}) == 0)

vim.cmd("tabnext 1")
vim.cmd("doautocmd TabEnter")
vim.cmd("doautocmd WinEnter")
check("markers re-placed after the other pane closed",
  #sign_rows(code_buf) == expected_marks)

-- toggle off closes every pane in every tab
sidebar.toggle()
local remaining = 0
for _, t in ipairs(api.nvim_list_tabpages()) do
  if find_pane(t) then remaining = remaining + 1 end
end
check("toggle off closed all panes", remaining == 0)
check("gutter marks cleared on close", #sign_rows(code_buf) == 0)
check("signcolumn restored", vim.wo[code_win].signcolumn == "auto")
check("augroup cleared", not pcall(function()
  return api.nvim_get_autocmds({ group = "codeboomer-review-pane" })
end))

-- reopen, and prove any window in the tab can drive the pane
sidebar.toggle()
check("pane reopens", find_pane(api.nvim_get_current_tabpage()) ~= nil)
vim.cmd("vsplit")
vim.cmd("doautocmd WinEnter")
local other = api.nvim_get_current_win()
check("second split in tab drives pane", vim.wo[other].signcolumn == "auto:2")

print(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
os.exit(fails == 0 and 0 or 1, true)
