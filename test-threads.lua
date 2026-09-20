-- headless test for the thread-pair model: local/review halves,
-- promotion, the two outboxes, the resolve cascade, agent diversion
-- and gh pull matching. Run exactly like test-sidebar.lua:
--   XDG_DATA_HOME=/tmp/xdg-isolate nvim --headless -u NONE \
--     --cmd "set rtp^=$PWD" -c 'luafile test-threads.lua'
-- (cwd = repo root; SELF-SEEDING and wipes the DB at the end)
local fails = 0

local function check(desc, cond)
  if cond then
    print(("PASS  " .. desc))
  else
    fails = fails + 1
    print(("FAIL  " .. desc))
  end
end

-- a real file buffer so git.head-sha resolves (the anchor fallback)
vim.cmd("edit fnl/codeboomer/init.fnl")

local review = require("codeboomer.review")
local github = require("codeboomer.github")

local sid = review["create-session"]({})
review["set-session"](sid)

-- ── annotate → discuss: everything stays on the local half ─────────
review["user-comment"](sid, "fnl/codeboomer/init.fnl", 10, 12, "code A", "annotation A")
local threads = review["threads-for-session"](sid)
check("annotation is born a local root", #threads == 1 and threads[1].kind == "local")
local a = threads[1]

review["agent-reply"](a.id, "agent pushback")
review["user-reply"](a.id, "user negotiation") -- the a key's row
check("conversation interleaves by creation",
  #review["conversation-comments"](a.id) == 3)

check("unpromoted: no review half", review["twin"](a.id) == nil)
check("unpromoted: posting outbox empty", #review["pending-for-post"](sid) == 0)
check("unpromoted: flush outbox holds the user messages (agent words never)",
  #review["pending-for-flush"](sid) == 2)

-- ── promote: the one door into the posting outbox ──────────────────
local twin_id = review.promote(a.id, "final wording", sid, nil)
local twin = review["twin"](a.id)
check("promote creates the review half",
  twin ~= nil and twin.kind == "review" and twin.id == twin_id)
check("promote anchors in the given session", twin and twin.session_id == sid)
check("second promote refuses", review.promote(a.id, "again", sid, nil) == nil)
check("promote refuses empty text",
  review.promote(999999, "", sid, nil) == nil)
check("conversation spans both halves",
  #review["conversation-comments"](a.id) == 4)

local post = review["pending-for-post"](sid)
check("posting outbox = the promoted comment only",
  #post == 1 and post[1].comment.body == "final wording"
    and post[1].thread.id == twin_id)
check("flush outbox now includes the promoted text (agent sees it too)",
  #review["pending-for-flush"](sid) == 3)

-- r on the promoted pair: a reply on the review half ships later
review["user-reply"](twin_id, "reviewer reply")
check("reply on the review half joins the posting outbox",
  #review["pending-for-post"](sid) == 2)

-- e: rewrite the promoted comment in place
local unposted = review["unposted-user-comments"](twin_id)
check("unposted-user-comments: promoted first, reply second",
  #unposted == 2 and unposted[1].body == "final wording")
review["update-comment-body"](unposted[1].id, "final wording v2")
post = review["pending-for-post"](sid)
check("edit rewrites the promoted comment in place",
  #post == 2 and post[1].comment.body == "final wording v2")

-- the fold: a pair is ONE logical thread
check("the pair folds into one logical thread",
  #review["threads-for-session"](sid) == 1)

-- ── resolve cascades both halves ───────────────────────────────────
review["resolve-thread"](a.id)
check("resolve closes the whole pair",
  #review["threads-for-session"](sid) == 0
    and #review["review-rows-for-session"](sid) == 0
    and #review["pending-for-post"](sid) == 0)

-- ── pulled thread: born review; agent discussion diverts ───────────
local pulled = review["import-thread"](sid, {
  id = 555, path = "fnl/codeboomer/init.fnl", line = 40,
  body = "reviewer note", user = { login = "somebody" }, commit_id = "abc123",
})
check("pulled thread is born :review",
  review["review-rows-for-session"](sid)[1].kind == "review")
review["agent-reply"](pulled, "agent take")
local local_twin = review["twin"](pulled)
check("agent reply diverts to a fresh local twin",
  local_twin ~= nil and local_twin.kind == "local"
    and #review["comments-for"](pulled) == 1
    and #review["comments-for"](local_twin.id) == 1)
check("gh root stays the pulled comment",
  review["gh-root-comment-id"](pulled) == "555")
check("agent words on the twin never enter the posting outbox",
  #review["pending-for-post"](sid) == 0)

-- ── posted comment come home: stamp instead of duplicate ───────────
review["user-comment"](sid, "README.md", 5, 5, "code B", "posted wording")
local tb
for _, t in ipairs(review["threads-for-session"](sid)) do
  if t.file_path == "README.md" then tb = t end
end
local tb_twin_id = review.promote(tb.id, "posted wording", sid, nil)
local pc = review["pending-for-post"](sid)[1].comment
check("the README pair is the only thing postable", pc.body == "posted wording")
review["mark-annotations"]("posted", { pc.id })

local item = {
  id = 987, path = "README.md", line = 5, body = "posted wording",
  user = { login = "me" },
}
local mine = review["match-posted-comment"](sid, item)
check("a come-home comment matches back onto its row",
  mine ~= nil and mine.id == pc.id)
check("import stamps instead of duplicating",
  github["import-items"](sid, { item }) == 1)
check("re-pull is idempotent", github["import-items"](sid, { item }) == 0)
check("stamped comment found by gh id", review["comment-by-gh"](987) ~= nil)
local n_readme = 0
for _, t in ipairs(review["threads-for-session"](sid)) do
  if t.file_path == "README.md" then n_readme = n_readme + 1 end
end
check("no duplicate thread for the come-home comment", n_readme == 1)
check("the promoted pair gains its gh root (r-replies route to replies)",
  review["gh-root-comment-id"](review["twin"](tb.id).id) == "987")

-- ── the off-diff predicate (pure) ───────────────────────────────────
check("thread-off-diff: outside refused, inside accepted",
  github["thread-off-diff"](
    { file_path = "README.md", line_start = 5, line_end = 5 },
    { ["README.md"] = { { 1, 4 } } }) == true
    and github["thread-off-diff"](
      { file_path = "README.md", line_start = 5, line_end = 5 },
      { ["README.md"] = { { 1, 9 } } }) == false)

-- wipe the seeded rows — leave the DB as empty as it was found
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
