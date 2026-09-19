-- headless smoke test for the review-scoped comments pane + markers
-- run: nvim --headless -u NONE --cmd "set rtp^=..." -c "luafile test-sidebar.lua"
-- (cwd = repo root; SELF-SEEDING: creates a session and two overlapping
-- threads through the real write path, and wipes them again at the end —
-- the DB is expected to start empty and is left empty)
--
-- the pane and the gutter markers exist ONLY inside reviews: review-mode
-- stamps every worktree buffer with codeboomer_review_side and that
-- stamp is the gate. The test stamps a plain working buffer by hand —
-- exactly what review-mode's configure-code-buffer does — so the real
-- gate, not a bypass of it, decides what renders.
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

-- target file: thread #1 at 3-3, thread #2 at 1-69 (overlap on line 3)
vim.cmd("edit fnl/codeboomer/init.fnl")
local code_win = api.nvim_get_current_win()
local code_buf = api.nvim_win_get_buf(code_win)
local tab1 = api.nvim_get_current_tabpage()

local review = require("codeboomer.review")
local sid = review["create-session"]()
-- review mode's setup-review always chooses the session before the
-- pane opens — reload-threads no longer adopts a sole session by
-- itself, so mirror the real flow here
review["set-session"](sid)
-- thread paths are stored repo-relative (like Annotate's context), so
-- seed with the relative path the real write path produces
review["user-comment"](sid, "fnl/codeboomer/init.fnl", 3, 3, "code A", "testing")
review["user-comment"](sid, "fnl/codeboomer/init.fnl", 1, 69, "code B", "another test")
-- a second comment on the 3-3 thread: the pane must render the two as
-- separate labeled messages, not one wall of text
for _, t in ipairs(review["threads-for-session"](sid)) do
  if t.line_start == 3 and t.line_end == 3 then
    review["user-reply"](t.id, "a reply")
  end
end

local sidebar = require("codeboomer.sidebar")
-- review mode loads the thread map when the review opens — load it
-- here by hand so the checks below see the seeds
sidebar["reload-threads"]()

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
local threads = review["threads-for-session"](sid)

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

-- ── local (unstamped) buffers: no pane, no marks — the review gate ─
rest(code_win, 3)
check("local buffer: resting in a range opens no pane", find_pane(tab1) == nil)
check("local buffer: no marks", #sign_rows(code_buf) == 0)

-- ── stamped as a review's new side (what configure-code-buffer does) ─
vim.b[code_buf].codeboomer_review_side = "new"
sidebar["mark-buffer"](code_buf)
check("review buffer: marks placed", #sign_rows(code_buf) == expected_marks)
check("signcolumn left alone", vim.wo[code_win].signcolumn == "auto")
local three = {}
for _, m in ipairs(api.nvim_buf_get_extmarks(code_buf, ns, 0, -1, { details = true })) do
  if m[2] + 1 == 3 then three[#three + 1] = m end
end
check(("overlap line 3 carries ONE symbol (%d covering)"):format(covering(3)),
  #three == 1 and covering(3) >= 2)
check("symbol is a half-block bar", three[1] and three[1][4].sign_text == "▌ ")

-- the debounce: a plain cursor move into a range waits it out
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

-- ── comment separation: labels + blank lines inside a block ────
check("blank line after the thread header", both[2] == "")
check("first comment labeled [source] name", both[3]:match("^%[%w+%] ") ~= nil)
local n_labels = 0
for _, l in ipairs(both) do
  if l:match("^%[%w+%] ") then n_labels = n_labels + 1 end
end
check("every comment carries a label (3 total)", n_labels == 3)
local separated = false
for i = 1, #both - 2 do
  if both[i] == "" and both[i + 1]:match("^%[%w+%] ") and both[i + 2] == "a reply" then
    separated = true
  end
end
check("comments separated by a blank line", separated)

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

-- ── off every range: the pane keeps the last block (never collapses) ─
local last = pane_lines()
rest(code_win, 100)
check("off-range: pane keeps the last block", find_pane(tab1) ~= nil
  and vim.deep_equal(pane_lines(), last))

-- ── unstamped buffers never drive the pane or carry marks ──────────
vim.cmd("tabnew")
vim.cmd("doautocmd TabEnter")
local tab2 = api.nvim_get_current_tabpage()
vim.cmd("edit README.md")
vim.cmd("doautocmd BufEnter")
vim.wait(300)
check("unstamped file: no pane in its tab", find_pane(tab2) == nil)
check("the review tab's pane stays put", find_pane(tab1) ~= nil)
check("README carries no marks",
  #sign_rows(api.nvim_win_get_buf(api.nvim_get_current_win())) == 0)

-- ── the old side drops the marks (thread numbers are new-side ones) ─
vim.cmd("tabnext")
vim.b[code_buf].codeboomer_review_side = "old"
sidebar["mark-buffer"](code_buf)
check("old side: marks dropped", #sign_rows(code_buf) == 0)
vim.b[code_buf].codeboomer_review_side = "new"
sidebar["mark-buffer"](code_buf)
check("back on the new side: marks again", #sign_rows(code_buf) == expected_marks)

-- ── closing by hand: resting in a range reopens ────────────────────
rest(code_win, 3)
local _, pane1_win = find_pane(tab1)
api.nvim_win_close(pane1_win, true)
check("pane closed by :q stays closed", find_pane(tab1) == nil)
rest(code_win, 3)
check("pane reopens after resting again", find_pane(tab1) ~= nil)
-- the reopen built a fresh pane buffer — rebind so the helpers read it
pane_buf, pane_win = find_pane(tab1)

-- ── resolving must not leave a stale block on screen ────────────────
-- q resolving a thread must re-render what still covers the code line
-- (the scheduled check skips re-rendering when nothing covers the
-- row): resolve one of two covering threads — block count drops — and
-- then the last one — blank pane, window stays
local function rule_row(lines)
  for i, l in ipairs(lines) do
    if l:gsub("─", "") == "" and #l > 0 then return i end
  end
end

check("pane shows both threads", rule_row(pane_lines()) ~= nil)
-- cursor into the SECOND block (threads render in file order: 1-69
-- first, 3-3 second) and resolve it
api.nvim_set_current_win(pane_win)
api.nvim_win_set_cursor(pane_win, { rule_row(pane_lines()) + 1, 0 })
local q = vim.fn.maparg("q", "n", false, true)
q.callback()
vim.wait(300) -- let the reload's scheduled check run too
check("one resolved: pane re-rendered without the separator",
  rule_row(pane_lines()) == nil)
check("one resolved: remaining block still shown", #pane_lines() > 0)

-- resolve the last covering thread: blank pane, window kept
api.nvim_win_set_cursor(pane_win, { 1, 0 })
q.callback()
vim.wait(300)
check("last resolved: pane blanked",
  #pane_lines() == 1 and pane_lines()[1] == "")
check("last resolved: window stays open", find_pane(tab1) ~= nil)
check("all resolved: marks gone", #sign_rows(code_buf) == 0)

-- wipe the seeded rows — leave the DB as empty as it was found
-- (deletes in child-first order; a fresh with_open connection does not
-- necessarily run with pragma foreign_keys on, so cascades can't be relied on)
require("codeboomer.singleton")["get-db"]():with_open(function(d)
  d:execute("delete from comment")
  d:execute("delete from comment_thread")
  d:execute("delete from session")
  d:execute("delete from git_commit")
  d:execute("delete from repo")
  d:execute("delete from user")
end)

print(fails == 0 and "ALL PASS" or (fails .. " FAILURES"))
os.exit(fails == 0 and 0 or 1, true)
