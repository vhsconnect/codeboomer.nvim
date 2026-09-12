# Simplification plan

Decision document for reshaping the plugin around its two jobs. Not a
task list — the reasoning for what stays, goes, and changes, so future
edits can be checked against it.

## The two jobs

1. **Live review** — annotate my working files, flush to the agent in a
   tmux pane, the agent's replies land back in the threads. Works today.
2. **PR review without the GitHub UI** — the plugin talks to `gh` in
   both directions: pull a PR's changes and its comment threads down
   into the local DB, review in a read-only nvim layout, push my
   comments and replies back up as a PR review. The reverse direction —
   responding to others' reviews of my PR — is the same workflow with
   the checkout pointed at my own branch.

GitHub-the-system stays; GitHub-the-interface goes. `gh` is the only
transport.

## Keep — the invariant core

| Piece | Why it stays |
|---|---|
| tmux transport (`SetPane`/`SendPrompt`/`SendSelection`) | Goal 1's channel. Small, self-contained, shared machinery. |
| `Annotate` → DB threads, `FlushWithDirective` + `directives.fnl` | Goal 1's loop; the DB-as-outbox design is correct. |
| sqlite schema (`user`/`repo`/`commit`/`session`/`thread`/`comment`) | The model both goals share. `anchor_commit` and `code_snapshot` are what make threads portable. |
| `sidebar` gutter marks + thread pane + reply/resolve/next keys | The UI both goals share. |
| `agent.fnl` + generated shim | Closes goal 1's loop; nothing else does this. |
| `input.fnl` | Compose UI used by annotate and reply. |
| `git.fnl` | Primitives goal 2 builds on (already has remotes, branch, sha). |
| `github.fnl` | The up direction (post review via `gh api`, grouped by anchor commit — the existing logic is right). Extends to the down direction; see below. |

## Cut — serves neither job

1. **`AskOneOff` + `one-offs.fnl`** — a standalone quick-query gadget.
   Removing it also deletes: the one-off picker, `run-one-off` /
   `one-off-result`, the `submit-on-enter` option in `input.fnl` (which
   exists only for it), and its config plumbing.

Nothing else. With `gh` as the intended transport, `github.fnl` and the
`posted` flag earn their keep.

## Change — five things, in order

### 1. Repo-relative file paths (do first)

Threads store absolute paths today (`github.fnl` already has to undo
this with `rel-path`). Snapshot checkouts live at different absolute
paths per machine and per PR, and every `gh` payload wants repo-relative
paths. Normalize to repo-relative at write time; the sidebar resolves
buffer-name → relative via `git.repo-root`. This is the schema/semantics
fix everything else leans on.

### 2. Explicit sessions, bound to PRs (kill the singleton)

`with-session` and `active-session-id` both `error` on multiple
sessions. Goal 2 is multi-session by nature: one per PR under review,
plus the local live session. The schema is ready; add:

- `session.pr_number` (nullable — null means the local live session)
- `session.base_commit` (the PR base, for changed-range computation)
- a session picker (fzf, same shape as the pane picker); when it lists
  open PRs via `gh pr list`, choosing one *is* `:Codeboomer Review`
- sidebar / flush / annotate target the chosen session

### 3. Snapshot review mode — `:Codeboomer Review <pr>`

The core architectural piece, and the answer to the drift problem:

- Fetch the PR head (`git fetch origin pull/<n>/head` — works for fork
  PRs too) and `git worktree add --detach` at it. A worktree, not
  scratch buffers: real files mean LSP, quickfix, and every other
  plugin work; disposable via `git worktree remove`.
- Layout: **code left, comments right**. Code buffer is `nomodifiable`;
  threads anchor to the pinned head commit, so line numbers cannot
  drift *by construction*.
- Changed ranges marked in the gutter from
  `git diff --unified=0 base..head` hunk headers (`@@ +l,c @@`), styled
  distinctly from thread marks. These marks now do double duty:
  navigation *and* the boundary of where inline comments may anchor
  (GitHub rejects comments on non-diff lines — see §4).
- The comments pane becomes a *persistent* split instead of the
  ephemeral cursor-rest pane: `CursorMoved` just re-renders it for the
  thread under the cursor. In this mode the rest-debounce /
  one-pane-across-tabpages / floating-window-filtering machinery
  collapses — that complexity exists to manage an ephemeral pane, and a
  mode-owned persistent pane doesn't need it.
- `Annotate` / reply / resolve work unchanged on the snapshot (visual
  selection + `getregion` don't need modifiability).
- Thread `anchor_commit` = the PR head at fetch time. Because comments
  are fetched and the worktree checked out in the same pass, GitHub's
  current `line` values align with the snapshot exactly.

### 4. Sync down / sync up — `gh` both ways

The DB mirrors the PR conversation and holds the outbox, exactly like
the agent flow. Same pattern, second transport.

**Down** (`:Codeboomer Pull`, or folded into opening a PR session):
`gh api repos/<slug>/pulls/<n>/comments` (and the PR's review bodies)
→ threads + comments with `source :github`, keyed by
`comment.gh_comment_id` so re-pulls are idempotent — insert-once by ID,
no content matching ever. Thread grouping: `in_reply_to_id` chains, else
each top-level comment seeds a thread. Authors map through the existing
`user` table by email (GitHub payloads carry it).

**Up** (extend `github.fnl`'s existing `post-threads`):
- New annotations (no gh linkage) batch into one review per anchor
  commit — the existing `group-pending` logic, kept as is.
- Replies to fetched threads post via
  `POST .../pulls/<n>/comments/<gh_comment_id>/replies`.
- Delivery is **author-scoped**, settled: the outbox is
  `author = me ∧ source :user ∧ not posted` — exactly what
  `pending-annotations` already filters. Agent comments (`:agent`)
  and pulled-down comments (`:github`) are never push candidates,
  in any thread, on any session. No widening.
- Validate push targets against the changed ranges computed in §3:
  a comment whose range falls outside the diff is refused (or
  demoted to a review-body comment) *before* the API rejects it.

**Outdated comments** (GitHub's `position: null` after force-pushes or
new commits): their `line` refers to an older snapshot. MVP: import
them anchored best-effort at `original_line` with an `outdated` marker
in the thread header; don't attempt re-anchoring.

**The agent as co-reviewer** composes both jobs on one snapshot: in a
PR session, `Annotate` + `FlushWithDirective` send diff context to the
agent over tmux exactly as in live review (annotating a
`nomodifiable` worktree buffer works — selection needs no edits); the
agent's replies land in the same threads via the shim with
`source :agent`, render in the comments pane next to the PR threads,
and are never posted. My comments in those same threads post normally
— the agent's review of a PR and mine coexist in one session with
different delivery fates, decided per comment by authorship.

### 5. Drift policy for live review (goal 1) — defer, don't solve

Do not build general re-anchoring. The mitigations that already exist
are the right ones: `code_snapshot` rides along in every flush so the
agent relocates by content; marks/pane tolerate staleness. Add, when
annoying enough: mark threads stale when head moves, and a best-effort
re-anchor that exact-match searches the snapshot's edge lines in the
current buffer. Anything fuzzier than exact-match is a trap.

## The hard parts, named, with the chosen dodge

| Hard part | Dodge |
|---|---|
| Line-number drift | Read-only snapshot mode pinned to the PR head. Not solved in general; not solvable in general. |
| Rendering "the whole change" | Full files + changed-range marks. No virtual diff buffers, no hunk/line mapping. |
| Round-trip identity | `gh_comment_id` on comment rows — GitHub's stable IDs, no content hashing. |
| Inline comments must land on diff lines | Changed ranges are computed anyway for rendering; validate pushes against them locally. |
| Outdated comments after new commits | Import with `original_line` + an outdated marker; no re-anchoring. |
| Concurrent reviews | Explicit sessions + picker, `pr_number` binding. Schema is nearly ready. |
| Absolute paths | Normalize to repo-relative first. |

## Non-goals (the surface-area fence)

- No diff-buffer with virtual line numbers.
- No re-anchoring threads across edits/commits beyond exact-match.
- No transport other than `gh` — no file export, no server, no git notes.
- Nothing authored by the agent ever leaves the machine: publication is
  author-scoped, and only my comments are ever push candidates.
- No background services, watchers, or daemons — sync happens when a
  command runs.
- No multi-user concurrency inside one DB — GitHub is the sync point
  for PR sessions; the flush outbox is the sync point for live ones.

## Correctness sharp edges to fix while in the area

- `sqlite.fnl` DB path is hardcoded `/home/vhs/...` — derive from
  `stdpath(:data)`.
- `reload-threads` re-snaps marks to stale DB lines after out-of-nvim
  edits (the agent's edits) — in snapshot review mode this class of bug
  disappears; for live review it's covered by the drift policy above.
- `paste-text` / pane commands interpolate through `io.popen` shells —
  move to `vim.system` with argv lists.
- `parse-panes`' multiline pattern is fragile; a plain split would do.

## Sequencing

| Phase | Content | Done when |
|---|---|---|
| 0 | Cut `AskOneOff` + `one-offs.fnl` (+ `submit-on-enter`) | Commands/docs gone, plugin smaller |
| 1 | Rel-path normalization; sessions get `pr_number`/`base_commit`, picker; `comment.gh_comment_id` | Two sessions coexist; PR session binds |
| 2 | Review mode MVP: PR head worktree, layout, annotate-on-snapshot, changed-range marks | A full local review of a PR, no pushing |
| 3 | Push up (extend `post-threads`, replies endpoint, diff-line validation) | Local annotations land on the PR |
| 4 | Pull down (fetch comments → threads, idempotent by gh id, outdated marker) | A colleague's review of my PR appears in review mode; I reply locally; the reply posts |
