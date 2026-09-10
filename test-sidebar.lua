-- headless smoke test for the ephemeral review-comments pane
-- run: nvim --headless -u NONE --cmd "set rtp^=..." -c "luafile test-sidebar.lua"
-- (cwd = repo root; the shell wrapper widens thread 2 to overlap thread 1
-- and restores it afterwards; DB reads only)
--
-- the pane opens only after the cursor RESTS ~100 ms inside a thread's
-- range (the debounce), so every cursor move below is followed by a
-- vim.wait — headless -c scripts never process real input, and the same
-- callback paths real interaction takes are driven with `doautocmd`.
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

-- move + wait out the 100 ms rest delay so the debounce timer fires
local function rest(win, line)
  api.nvim_win_set_cursor(win, { line, 0 })
  vim.cmd("doautocmd CursorMoved")
  vim.wait(300)
end

-- target file: thread #1 at 3-3, thread #2 widened to 1-69 by the wrapper
vim.cmd("edit fnl/codeboomer/init.fnl")
local code_win = api.nvim_get_current_win()
local code_buf = api.nvim_win_get_buf(code_win)
local tab1 = api.nvim_get_current_tabpage()

local sidebar = require("codeboomer.sidebar")
-- -c chunks run BEFORE VimEnter, and os.exit kills nvim before the main
-- loop would fire it — trigger the startup thread-map load by hand
vim.cmd("doautocmd VimEnter")

local function find_pane(tab)
  for _, w in ipairs(api.nvim_tabpage_list_wins(tab)) do
    local b = api.nvim_win_get_buf(w)
    if api.nvim_buf_get_name(b):find("^codeboomer://review%-comments") then
      return b, w
    end
  end
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

-- expected coverage straight from the DB — the dev DB keeps growing as
-- the plugin gets used, so nothing is hardcoded
local review = require("codeboomer.review")
local ok, sid = pcall(function() return review["active-session-id"]() end)
local threads = (ok and sid)
  and review["threads-for"](sid, api.nvim_buf_get_name(code_buf)) or {}

-- union of commented lines — one mark per line, overlaps included once
local covered = {}
local expected_marks = 0
for _, t in ipairs(threads) do
  for l = t.line_start, t.line_end do
    if not covered[l] then
      covered[l] = true
      expected_marks = expected_marks + 1
    end
  end
end

local function covering(line)
  local n = 0
  for _, t in ipairs(threads) do
    if line >= t.line_start and line <= t.line_end then n = n + 1 end
  end
  return n
end

-- ── gutter markers: always visible, independent of the toggle ─────
check("marks placed at startup", #sign_rows(code_buf) == expected_marks)
check("signcolumn left alone", vim.wo[code_win].signcolumn == "auto")
local three = {}
for _, m in ipairs(api.nvim_buf_get_extmarks(code_buf, ns, 0, -1, { details = true })) do
  if m[2] + 1 == 3 then three[#three + 1] = m end
end
check(("overlap line 3 carries ONE symbol (%d covering)"):format(covering(3)),
  #three == 1 and covering(3) >= 2)
check("symbol is a crayon", three[1] and three[1][4].sign_text == "✎ ")

-- ── the pane: opens on rest, collapses off range ──────────────────
-- park the cursor on an un-commented line before toggling on
rest(code_win, 100)
sidebar.toggle()
check("toggle on off-range: no pane", find_pane(tab1) == nil)

-- toggle-on while resting inside a range opens the pane immediately —
-- an explicit enable needn't wait out the rest delay
rest(code_win, 3)
sidebar.toggle()
sidebar.toggle()
check("toggle on inside a range opens immediately", find_pane(tab1) ~= nil)

-- a plain cursor move into a range does wait out the debounce
rest(code_win, 100)
api.nvim_win_set_cursor(code_win, { 3, 0 })
vim.cmd("doautocmd CursorMoved")
check("no pane before the rest delay elapses", find_pane(tab1) == nil)
vim.wait(300)

local pane_buf, pane_win = find_pane(tab1)
check("pane opened after resting on line 3", pane_win ~= nil)
check("cursor stayed in code window", api.nvim_get_current_win() == code_win)
check("pane is nofile + unmodifiable", vim.bo[pane_buf].buftype == "nofile"
  and vim.bo[pane_buf].modifiable == false)

local function pane_lines()
  return api.nvim_buf_get_lines(pane_buf, 0, -1, false)
end

local function has_rule(lines)
  for _, l in ipairs(lines) do
    if l:gsub("─", "") == "" and #l > 0 then return true end
  end
  return false
end

local both = pane_lines()
check("line 3 -> pane shows both overlapping threads", #both > 3 and has_rule(both))
print("      pane: " .. table.concat(both, " / "))

-- a line covered by exactly one thread renders a single block
local single = nil
for l = 12, 69 do
  if covering(l) == 1 then single = l break end
end
if single then
  rest(code_win, single)
  check(("line %d -> single thread, no separator"):format(single),
    not has_rule(pane_lines()))
end

-- off every range: the split collapses (not blanks)
rest(code_win, 100)
check("line 100 -> pane collapsed", find_pane(tab1) == nil)
check("marks survive pane collapse", #sign_rows(code_buf) == expected_marks)

-- ── the toggle gates the pane only ────────────────────────────────
sidebar.toggle() -- off
rest(code_win, 3)
check("toggle off: resting in a range opens nothing", find_pane(tab1) == nil)
check("toggle off: marks stay", #sign_rows(code_buf) == expected_marks)
sidebar.toggle() -- back on

-- ── one pane globally, following the cursor across tabs ──────────
rest(code_win, 3)
check("pane back in tab 1", find_pane(tab1) ~= nil)
vim.cmd("tabnew")
vim.cmd("doautocmd TabEnter")
local tab2 = api.nvim_get_current_tabpage()
vim.cmd("edit README.md")
vim.cmd("doautocmd BufEnter")
vim.wait(300)
check("threadless file: no pane in tab 2", find_pane(tab2) == nil)
check("entering tab 2 collapsed tab 1's pane", find_pane(tab1) == nil)
check("README carries no marks", #sign_rows(api.nvim_win_get_buf(api.nvim_get_current_win())) == 0)

-- same file from tab 2: its own pane opens, still exactly one
vim.cmd("edit fnl/codeboomer/init.fnl")
vim.cmd("doautocmd BufEnter")
rest(api.nvim_get_current_win(), 3)
check("pane opens in tab 2", find_pane(tab2) ~= nil)
check("shared buffer not double-marked", #sign_rows(code_buf) == expected_marks)

-- back to tab 1 (cursor still resting in a range there): the pane
-- moves back with focus
vim.cmd("tabnext")
vim.cmd("doautocmd WinEnter")
vim.wait(300)
check("pane follows focus back to tab 1", find_pane(tab1) ~= nil)
check("tab 2 left without a pane", find_pane(tab2) == nil)

-- ── closing by hand collapses; resting reopens ────────────────────
local _, pane1_win = find_pane(tab1)
api.nvim_win_close(pane1_win, true)
check("pane closed by :q stays closed", find_pane(tab1) == nil)
rest(code_win, 3)
check("pane reopens after resting again", find_pane(tab1) ~= nil)

-- ── toggle off collapses everywhere, markers keep their hooks ─────
sidebar.toggle()
check("toggle off collapsed the pane", find_pane(tab1) == nil and find_pane(tab2) == nil)
check("marks survive toggle off", #sign_rows(code_buf) == expected_marks)
check("augroup kept for markers",
  pcall(function() return api.nvim_get_autocmds({ group = "codeboomer-review-pane" }) end))

print(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
os.exit(fails == 0 and 0 or 1, true)
