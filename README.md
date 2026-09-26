# codeboomer.nvim

A Neovim plugin for sending text and commands to tmux panes. Useful for sending text blocks to a repl or an AI agent along with some comments or instructions. 

## Features

- Send text from Neovim to any tmux pane
- Fuzzy-finder interface (via fzf-lua) to select target panes, showing each pane's last output line and working directory, with a live content preview
- Visual mode support — send the selection as-is (`SendSelection`) or as context in a composed prompt (`SendPrompt`)
- Annotation workflow — accumulate multiple code selections for review before sending
- **Review sessions (`Sessions`)** — annotations are grouped into sessions (one per branch or PR); annotate and flush all target the chosen one, the picker appears only when several compete, and `d` in the picker soft-deletes a session — its threads and comments vanish everywhere while the rows stay, the way to terminate a set of comments and start fresh
- **PR snapshot review (`Review`)** — fetch a PR head into a read-only worktree, tint its changed lines, and annotate it in a dedicated tab with the comments pane pinned open; `ReviewSide` flips the same review onto the base code so removed lines are readable (and tinted) too; `WalkForward`/`WalkBack` step through the PR's own commits one at a time (the pane shows each thread's anchor commit next to the one currently shown, since walking doesn't re-anchor); opening a PR also imports its inline comments as threads, and `PostReview` pushes the threads you **promoted** (the pane's `p`) up as a pending review (a draft submitted on GitHub); `ReviewWorktree` gives uncommitted working-tree changes (e.g. an agent's edits) the same read-only treatment via a dangling snapshot commit
- **Local/review thread halves** — every annotation starts as a local conversation with the agent (annotate, `a`-replies, agent answers via the shim); `p` in the comments pane promotes a thread: the shipping half is born with the final wording, anchored at the pinned PR head, after an off-the-diff refusal. Nothing reaches `PostReview` without that deliberate step — agent chatter and your negotiation with it are structurally unshippable
- **Review comments pane** — inside an open review (`Review` / `ReviewWorktree`) commented ranges carry gitsigns-style `▌` gutter bars (colored per thread) and a side split follows the cursor: rest it inside a commented range and the thread's comments appear — both halves interleaved as one conversation; window-navigate into it, where `r` replies on the review half (promoted threads and pulled ones), `a` replies to the agent, `p` promotes, `e` edits the promoted comment, `q` resolves and `n` hops to the next thread. Local self-review (annotate, flush) is marker-free
- Bracketed-paste support for proper multi-line handling
- **One-off queries (`AskOneOff`)** — spawn a single process for a quick task without maintaining a session or requiring a tmux pane; define any number of user-named one-off commands and pick one with fzf when there is more than one

## Installation

```lua
-- lazy.nvim
{
  "vhsconnect/codeboomer.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("codeboomer").setup({
      -- Optional: customize keybindings (set to false to disable)
      keybindings = {
        pane = "<leader>cp",            -- pick a tmux pane
        send_prompt = "<leader>cs",     -- send a prompt to the pane
      },
    })
  end,
}
```

## Configuration

### Keybindings

The plugin sets up no default keybindings; configure them like this:

| Mode | Binding | Description |
|------|---------|-------------|
| Normal + Visual | `<leader>cs` | `SendPrompt` — open the prompt; the selection is included as context when invoked visually |
| Visual | `<leader>cr` | `SendSelection` — send the selection to the pane as-is, then press Enter |
| Normal + Visual | `<leader>cc` | `AskOneOff` — run a one-off query; the answer is shown in a notification |
| Normal | `<leader>cp` | `SetPane` — pick a tmux pane to send messages to |
| Normal | `<leader>cS` | `Sessions` — manage review sessions (pick, create, `d` deletes) |
| Normal | `<leader>cR` | `Review` — snapshot-review a pull request in a read-only worktree |
| Normal | `<leader>cW` | `ReviewWorktree` — review the uncommitted working tree as a read-only snapshot |
| Normal | `<leader>ct` | `ReviewSide` — toggle the open review between the new and the old code |
| Normal | `<leader>c]` | `WalkForward` — step the open review forward one of the PR's own commits |
| Normal | `<leader>c[` | `WalkBack` — step the open review back one of the PR's own commits |
| Normal | `<leader>cP` | `PostReview` — push the promoted threads to the PR |
| Normal | `<leader>cL` | `PullReview` — pull the PR's inline comments into the session |
| Normal + Visual | `<leader>ca` | `Annotate` — add the selection (plus an optional note) to the query context; from normal mode, a whole-file comment |
| Normal | `<leader>cd` | `FlushWithDirective` — flush accumulated annotations with a directive |

Disable or customize any binding under `keybindings` in `setup()` (set to `false` to disable):

```lua
require("codeboomer").setup({
  keybindings = {
    send_prompt = "<leader>cs",
    send_selection = "<leader>cr",
    ask_one_off = "<leader>cc",
    flush_with_directive = "<leader>cd",
    pane = "<leader>cp",
    session = "<leader>cS",
    review = "<leader>cR",
    review_worktree = "<leader>cW",
    review_side = "<leader>ct",
    walk_forward = "<leader>c]",
    walk_back = "<leader>c[",
    post_review = "<leader>cP",
    pull_review = "<leader>cL",
    annotate = "<leader>ca",
  },
})
```

### Prompting

`<leader>cd` (`:Codeboomer FlushWithDirective`) picks a directive from a
fzf-lua menu — by default the two built-ins, `Review - converse` and
`Review - execute`. Pass your own list under `prompting.directives` in
`setup()` to add to or override it:

```lua
require("codeboomer").setup({
  prompting = {
    directives = {
      -- a label matching a built-in overrides it in place
      { label = "Review - converse", text = "Reply point by point, then wait." },
      -- new labels are appended after the built-ins
      { label = "Explain", text = "Explain the selected code. No changes." },
    },
  },
})
```

Each entry needs a `label` (shown in the fzf menu) and a `text` (the message
sent along with any accumulated annotations). Omitting `prompting.directives`
keeps the built-ins as-is.

`prompting.one_off_commands` defines the one-off commands `<leader>cc`
(`:Codeboomer AskOneOff`) can run: a list of entries, each with a `label`
(shown in the fzf picker and the input title) and a static `argv` list. The
composed prompt is appended to `argv` as the final argument when the command
runs. Entries may also set `timeout` (milliseconds; 60000 by default). When
unset, the list defaults to a single built-in entry:

```lua
require("codeboomer").setup({
  prompting = {
    one_off_commands = {
      -- a label matching a built-in overrides it in place
      { label = "claude-code (haiku)",
        argv = { "claude-code", "--model", "haiku", "--output-format", "json",
                 "--permission-mode", "acceptEdits", "-p" } },
      -- new labels are appended after the built-ins
      { label = "Deep",
        argv = { "claude-code", "--model", "opus", "--output-format", "json", "-p" },
        timeout = 300000 },
      { label = "Local", argv = { "ollama", "run", "qwen2.5-coder" } },
    },
  },
})
```

When more than one command is defined, `AskOneOff` opens an fzf picker
(each entry shows its label, argv, and a non-default timeout) before the
input UI; a single configured command runs directly without a picker.

Point entries at whatever the machine at hand provides — a plain binary, a
container wrapper, a nix flake invocation, … Output that is JSON with a
`result` field is shown as just the result; anything else is displayed raw.

### Debugging

Set `debug = true` in `setup()` to get database-call notifications.
Table operations are debounced per table — queries on the same table
within a second collapse into one notification carrying the count
(`querying 5 sqlite.thread`); raw-SQL `with_open` batches log one each
(`opening connection to sqlite`). Handy when tuning how often queries
run; off by default:

```lua
require("codeboomer").setup({ debug = true })
```

## Commands

### `:Codeboomer SendPrompt`

Opens the input UI and sends the composed message to the selected pane.

- With a visual range, the selection is included as context (`regarding <file> lines X to Y`), followed by the typed text
- Without a range, the current file name is sent as context (`regarding <file>`), followed by the typed text — use `SendSelection` for raw, unwrapped text

```
:'<,'>Codeboomer SendPrompt
```

### `:Codeboomer SendSelection`

Sends the visual selection to the selected pane **as-is** — no prompt, no context header. The lines are pasted with tmux bracketed paste and `Enter` is pressed.

- Requires a pane (picked first if none is selected)
- Requires a visual range

```
:'<,'>Codeboomer SendSelection
```

### `:Codeboomer SetPane`

Opens fzf-lua to select a target tmux pane. Each entry shows the running
command, location, working directory, mode, and last output line; a live
preview shows the pane's recent content.

### `:Codeboomer Review [pr]`

Opens a snapshot review of a pull request: the PR head is fetched
(`git fetch origin pull/<n>/head`) along with its base branch, checked
out as a detached worktree, and opened in a review tab — code on the
left, the review-comments pane on the right. The tab's cwd (`:tcd`) is
set to the worktree, scoped to that tab alone, so LSP servers spawned
inside it resolve project config (tsconfig, etc.) against the worktree
instead of wherever nvim itself was launched from.

- Without an argument an fzf picker over `gh pr list` opens — choosing
  a PR *is* opening its review; with a number the picker is skipped.
  Requires `gh` and a GitHub-hosted remote
- Code buffers are read-only (`nomodifiable`/`readonly`): threads
  anchor to the pinned PR head, so line numbers cannot drift by
  construction
- Changed lines (merge-base..head — the same three-dot shape GitHub
  diffs) carry a `DiffAdd` tint; a quickfix of the changed files opens
  with the review and reopens via `:Codeboomer ReviewFiles`
- `:Codeboomer ReviewSide` (`<leader>ct`) flips the worktree onto the
  base side of the same diff: the lines the PR removed or rewrote are
  the tinted ones there (DiffDelete red — the new side keeps its
  DiffAdd green), and files the PR deleted are readable again. The
  cursor and scroll position stay put across the flip. Annotations
  still anchor to the head — `Annotate` and the gutter bars are off
  while the old side is shown
- Inside review buffers `]a` / `[a` hop to the next / previous
  hunk of the shown side — within the file first, then wrapping
  across the changed files (the same in-memory range map the tints
  read, so hopping follows `ReviewSide` flips); the keys exist only
  in review buffers
- A PR-bound session is created (or found, keyed by `pr_number`) and
  chosen: `Annotate`, the comments pane and the gutter marks all
  target it; re-opening the same PR reuses its threads
- The review-comments pane lives in the review tab: resting the cursor
  (~100 ms) inside a commented range shows that thread's comments —
  one block per covering thread (overlaps pick the earliest range),
  `─`-separated, headers tinted in the thread's gutter color, every
  comment labeled `[source] name`, and a dimmed keymap footer under
  the blocks. Moving off every range keeps the last block on screen;
  `:q` closes the pane and the next rest reopens it. A cursor
  completely still for ~5 s re-queries the database in one pass — a
  trailing debounce every cursor move restarts, so at most one query
  per rest — and the pane re-renders from whatever came back wherever
  it sits (agent replies arrive from outside the editor): no landing
  back on the thread's line to see an update. Window-navigate
  into it (`<C-w> w`); buffer-local keys act on the thread whose
  block the cursor is in:

| Key | Action |
|-----|--------|
| `r` | Reply on the **review half** — the half that ships. Only exists once the thread is promoted (`p`) or pulled from GitHub; unpromoted threads refuse with a pointer to `p`, so nothing reaches the posting outbox by accident |
| `a` | Reply to the **agent** — the local conversation half (created on demand for pulled threads). Your side of any discussion with the agent; never ships |
| `p` | **Promote** — open the compose input prefilled with the annotation's wording and create the review half with the final text. A *virgin* thread (one user comment, nothing from the agent) promotes as-is with no input. Refuses without an open PR review, and when the range falls outside the PR diff |
| `e` | Edit the promoted comment in place (the oldest still-unposted one) through the same prefilled input |
| `q` | Resolve the thread — resolved threads are treated as soft-deleted: both halves of the pair leave the pane, the `▌` marks and both outboxes; the pane drops the block right away |
| `n` | Next thread — jumps the cursor back into the code window on the next thread of the session (wrapping at both ends); the pane follows via the usual rest detection |

- Commented ranges carry `▌` gutter bars in review buffers — one mark
  per line, colored per thread (theme groups `Title`, `Special`,
  `String`, `Function` cycled); the sign column is never modified. The
  pane and the bars exist only inside reviews: thread line numbers
  belong to the read-only snapshot, so local working buffers show
  neither
- Re-reviewing a PR reuses its worktree silently — discovered via
  `git worktree list`, no prompt. The first time a PR is reviewed, a
  floating input asks where to put it, prefilled with a sibling of the
  repo one directory up; the worktree is reused on re-review
  (hard-reset onto the new head) and disposed of with
  `git worktree remove`
- Opening the review also pulls the PR's inline comments down as
  threads (`:Codeboomer PullReview` refreshes — idempotent by GitHub
  comment id); `:Codeboomer PostReview` pushes your **promoted**
  threads up as a pending review — a draft you submit on GitHub
  (comment / approve / request changes), so nothing reaches the
  author until you do. Only user comments of review halves ever ship:
  agent-authored comments and the local conversation with the agent
  stay on your machine

```vim
:Codeboomer Review 42
```

### `:Codeboomer ReviewFiles [dir]`

Fills the quickfix list with the changed files of the open review and
opens it — one entry per file, its line number on the first changed
line (Enter jumps straight to the tint) and its text listing the
changed line groups (`L100, L140-155, …`, capped). The list's title
carries the side being shown, and an open list follows `ReviewSide`
flips in place — deleted files reappear on the old side — while a
closed one stays closed. `:cnext`/`:cprevious` step between files.

An optional argument scopes the list to a directory (or a single
file), git-diff-pathspec style — leading and trailing slashes are
ignored. The scope sticks across `ReviewSide` flips (the title shows
it); a bare `:Codeboomer ReviewFiles` resets to every changed file.

```vim
:Codeboomer ReviewFiles fnl/codeboomer
```

### `:Codeboomer ReviewSide`

Toggles the open review between the two sides of its diff. The default
is the new code (the head, `DiffAdd` tint); toggling checks the worktree
out at the base instead, so the lines the diff *removed* — invisible
in the new code — are readable and tinted `DiffDelete` red, and files
deleted by the change come back. The cursor and scroll position are
preserved across the flip (clamped when the other side is shorter).
Toggling again returns to the head. The old side is read-only in the
stronger sense too: annotations and the gutter bars anchor to the
new side's line numbers, so `Annotate` refuses there (flip back first)
and the bars hide.

```vim
:Codeboomer ReviewSide
```

### `:Codeboomer WalkForward` / `:Codeboomer WalkBack`

Steps the open review's worktree through the PR's own commits
(`base..head`, oldest first) one at a time — a bare checkout, same as
`ReviewSide`, with the cursor and scroll position preserved the same
way. Neither wraps: walking past either end warns instead. Walking
away from the head clears the changed-lines tint (what a single commit
touched isn't computed); landing back on the head restores it.
Threads don't re-anchor as you walk — each thread's pane header shows
its own **anchor** commit next to the commit currently **now** shown,
so drift is visible rather than silently wrong. Flipping `ReviewSide`
to the old code resets the walk position back to the head.

```vim
:Codeboomer WalkForward
:Codeboomer WalkBack
```

### `:Codeboomer ReviewWorktree [dir]`

Reviews the **uncommitted working tree** (optionally just one
directory's, git-diff-pathspec style — the same pathspec handler
`ReviewFiles` scopes with) against HEAD in the same read-only mode —
the bridge for reviewing agent-made changes before committing them.
The dirty state (untracked files included, ignored files excluded) is
snapshotted into a dangling commit via git plumbing
(`read-tree`/`write-tree`/`commit-tree`): the throwaway index is
seeded from HEAD and the working tree overlays only the scoped
pathspec, so a scoped snapshot's diff contains exactly that
directory's changes while nothing is committed, no ref moves, and
`git status` is untouched. A scope with nothing uncommitted warns and
opens nothing. Each run starts a fresh review session — no `gh`, no
network needed; git forgets the snapshot at the next gc.

```vim
:Codeboomer ReviewWorktree
:Codeboomer ReviewWorktree fnl/codeboomer
```

### `:Codeboomer Sessions`

Opens fzf-lua over the repository's review sessions plus a `+ new session`
entry. Each line shows the session id, what it reviews (`live`, or `PR <n>`
for PR-bound sessions), and the branch it was created on; the chosen session
is starred. Picking sets the session that `Annotate` and
`FlushWithDirective` operate on.

Press `d` to **delete** the highlighted session — softly: `deleted_at`
is set and the session's threads and comments vanish from every
listing and outbox (pane, marks, flush, post) while the rows stay in
the database. The picker list refreshes in place, and deleting the
chosen one clears the choice — the next write then starts a fresh
session (or adopts a sole survivor). A soft-deleted PR session is not
reused when you re-`Review` the same PR. Deleting the session of an
open review is refused: close the review first.

Session resolution is silent in the common cases: with nothing chosen, the
first write creates the first session, and exactly one existing session is
adopted automatically (on the first write). The picker appears only
when several sessions compete.

### `:Codeboomer PostReview`

Pushes the chosen PR session's **promoted** threads — the review halves
created by `p` in the comments pane — to GitHub. Nothing else can enter
the outbox: local conversation halves are unreachable from this walk.

- Comments land in a **pending review** — a draft on GitHub you
  submit there (comment / approve / request changes); nothing is
  published until you do
- File-level threads ship as GitHub file comments
  (`subject_type = file`) — exempt from the off-diff gate, since
  GitHub anchors them to the file rather than to diff lines
- Replies to pulled threads post via the replies endpoint (attached
  under the thread's root GitHub comment) — immediately, as that
  endpoint has no draft state; everything else batches into one
  pending review per anchor commit (the pinned PR head), so every
  inline comment resolves against the exact diff it was written on
- GitHub allows one pending review per user and PR: posting again
  while a draft is unsubmitted fails with a 422 — submit or discard
  the draft on GitHub first
- When a review is open, threads whose range falls outside the PR
  diff are refused locally first (the same check runs at promotion
  time) — GitHub would reject them anyway
- On success the comments are marked `posted` and never re-ship;
  failures surface the exit code and stderr. After you submit the
  draft on GitHub, `PullReview` matches your posted comments back
  onto their local rows (by path, body and line) instead of
  duplicating them — and the stamped gh ids give promoted pairs their
  GitHub root, so later `r` replies post through the replies endpoint
- Requires `gh` authentication and a GitHub remote

```vim
:Codeboomer PostReview
```

### `:Codeboomer PullReview`

Imports the PR's current inline comments into the chosen PR session as
threads — idempotent by GitHub comment id (re-pulls add only what's
new), replies joined to their threads, and comments GitHub marks
outdated anchored best-effort at their original line with an
`outdated` flag in the thread header. Whole-file PR comments
(`subject_type = file`) import as `type = file` threads — no lines,
never flagged outdated. A comment that is one of your
own posted ones (`PostReview` + submitted draft) comes home by
stamping its gh id onto the local review half instead of seeding a
duplicate thread. `:Codeboomer Review` runs this automatically after
opening; the comments pane of an open review reloads on arrival.

```vim
:Codeboomer PullReview
```

### `:Codeboomer AskOneOff`

Runs a one-shot query — a single process, no session or pane needed. The
answer is shown in a notification. Works with or without a visual selection
(included as context when present; without one, the current file name is
sent instead).

- If more than one one-off command is configured (see
  `prompting.one_off_commands`), an fzf picker — label plus argv per entry —
  opens first; a single configured command runs directly
- The input title shows the chosen command's label and submits on `<CR>` —
  `<C-j>` (insert mode) or `o` (normal mode) for a newline
- Runs asynchronously via `vim.system` (no shell interpretation, per-entry
  `timeout` defaulting to 60 s); failures surface the exit code and stderr
  in a notification

### `:Codeboomer Annotate`

Adds the current selection to the review session's annotation outbox. Use this to annotate multiple code sections before sending a directive.

- Requires a pane to be selected first via `:Codeboomer SetPane`
- With a visual range, the selection is included as context (`regarding <file> lines X to Y`); without one the annotation becomes a **whole-file comment** (`type = file`) — a thread anchored to the file itself with no line range — file paths are stored repo-relative
- The review session is resolved on write: the chosen one when set (see `:Codeboomer Sessions`), the sole existing one when exactly one exists, a fresh one when none does — a picker appears only when several compete
- Annotations are stored in the review session's database — the single store — each as its own **local conversation thread** (`kind = local`): tracked as not-yet-sent (agent) and invisible to `PostReview` until promoted in the comments pane (`p`). They are included in the next `:Codeboomer FlushWithDirective` call until sent
- Inside an open review (`Review` / `ReviewWorktree`), commented ranges
  get `▌` gutter marks and the comments pane shows a thread's comments
  when the cursor rests inside its range; file-level threads carry no
  lines, so they get no marks and the pane lists them with a `file`
  position instead of a line range
- Empty notes are ignored

```
:'<,'>Codeboomer Annotate
```

### `:Codeboomer FlushWithDirective`

> [!warn] **Tentative API** — This command is experimental and subject to change in future versions.

Opens fzf to select a pre-defined directive, then sends it along with all unsent annotations from `:Codeboomer Annotate` (threads resolved before the flush are soft-deleted and never ship).

- Requires a pane to be selected first via `:Codeboomer SetPane`
- Select from a list of pre-defined directives (see Configuration below for customizing)
- After sending, the delivered annotations are marked `sent` in the database — they persist (with their `▌` marks) but are never re-sent; annotations survive restarts because the database is the only outbox
- Each message carries one **whole thread**: the header (`regarding <file> lines X to Y (thread N)`), the annotated code, and the full conversation — every comment author-labeled (`[user] vhs: …`, `[agent] agent: …`, `[github] reviewer: …`), so a reply flushed to a pulled thread ships the GitHub reviewer's words along and a re-asked thread ships the agent's earlier answers. Several unsent comments of one thread ship as one conversation, not one copy each
- The payload ends with a reply instruction pointing at the generated `codeboomer-agent` shim — the agent answers each thread with `codeboomer-agent reply <thread-id> <text>`, which appends an agent comment to that thread in the database (visible
in the comments pane of an open review on its next reload)
- The shim is also self-documenting: `codeboomer-agent help` (equally `-h`, `--help`, or no arguments at all) prints its full usage, so an agent that's only been handed the path can work out how to use it without any of the above spelled out in a prompt

```vim
:Codeboomer FlushWithDirective
```

## How it works

### Basic workflow

1. Select a pane with `<leader>cp` or `:Codeboomer SetPane`
2. Send a prompt with `<leader>cs` (`:Codeboomer SendPrompt`), or send the selection as-is with `<leader>cr` (`:Codeboomer SendSelection`)

### Annotation workflow

For more complex queries, you can build up context across multiple selections:

1. Select a pane with `<leader>cp`
2. Select code sections and run `<leader>ca` (or `:Codeboomer Annotate`) to add annotations to your query
3. When ready, run `<leader>cd` (or `:Codeboomer FlushWithDirective`) to send your directive along with all unsent annotations — the database is the outbox, so annotations survive restarts
4. The agent answers each thread back with `codeboomer-agent reply <thread-id> <text>` (the instruction is included in the payload); replies land in the same threads — for a pulled thread they join a local twin created on demand — and show up in the comments pane of an open review (`Review` / `ReviewWorktree`), where you can also answer threads yourself — window-navigate into the pane, then `a` to talk to the agent, `r` to reply on the review half, `q` to resolve

A review session is created (or the sole existing one adopted) on the first
annotation; `:Codeboomer Sessions` (`<leader>cS`) switches when several
exist — annotations, flushes and gutter marks all follow the chosen session.

### PR review workflow (local)

1. `<leader>cR` (`:Codeboomer Review`) — pick a PR; its head lands in a
   read-only worktree with changed lines tinted, in a tab with the comments
   pane on the right
2. Jump between changed files with `:Codeboomer ReviewFiles` (Enter
   lands on the first tinted line); annotate selections with
   `<leader>ca` as usual — the snapshot is read-only, but
   annotations only need a selection; flip to the base code with
   `<leader>ct` (`:Codeboomer ReviewSide`) to read what a change
   removed; `]a`/`[a` step between hunks of the shown side
3. Threads show in the comments pane — `a` discusses with the agent,
   `q` resolves, `n` hops to the next thread
4. `p` promotes the survivors: the compose input opens prefilled with
   the annotation's wording (virgin threads promote as-is), the review
   half anchors at the pinned PR head, and the header gains
   `· promoted`; `e` refines the wording afterwards
5. `:Codeboomer PostReview` (`<leader>cP`) pushes the promoted threads
   to the PR when you're ready — nothing ships until you say so;
   `:Codeboomer PullReview` (`<leader>cL`) refreshes the PR's
   comments (your submitted ones match back onto their rows).
   Agent-authored comments never ship

## Development

This plugin is written in **Fennel** and compiled to Lua using **nfnl** (embedded directly in the repo under `lua/nfnl/`).

### How the build works

Edit `.fnl` files under `fnl/`; **nfnl** auto-compiles them to `.lua` under
`lua/` on save. The `.lua` files are generated (marked by an `[nfnl]` header)
and never hand-edited.

### nfnl commands

These are available automatically when nfnl is loaded (no extra config needed):

| Command | Description |
|---------|-------------|
| `:NfnlCompileFile` | Compile the current (or given) `.fnl` file to Lua |
| `:NfnlCompileAllFiles` | Compile every `.fnl` file in the project |
| `:NfnlFindOrphans` | List `.lua` files with no matching `.fnl` source |
| `:NfnlDeleteOrphans` | Delete those orphan `.lua` files |
| `:NfnlFile` | Execute a compiled `.lua` file from disk |

### Setting up a dev environment

For testing the repo's copy against your **regular** Neovim config (it is prepended to the runtimepath, so it shadows any installed version — rebuild artifacts with `nfnl` first), use `./test-codeboomer`. It requires `CODEBOOMER_PATH` to point at the plugin directory and wires up the full keymap set (`<leader>cs`, `<leader>cr`, `<leader>cc`, `<leader>cd`, `<leader>cp`, `<leader>cS`, `<leader>cR`, `<leader>cW`, `<leader>cP`, `<leader>cL`, `<leader>ca`). Extra arguments pass through to nvim, so you can land straight in a review:

```bash
CODEBOOMER_PATH=$PWD ./test-codeboomer                          # plain launch
CODEBOOMER_PATH=$PWD ./test-codeboomer -c 'Codeboomer Review'    # opens the PR picker
CODEBOOMER_PATH=$PWD ./test-codeboomer -c 'Codeboomer Review 42' # straight to PR 42
```

(The review commands need `gh` authentication and network — the PR head and base branch are fetched, and the review opens in its own tab once the picker resolves.)

The headless smoke tests are `test-sidebar.lua` (the review-scoped
comments pane and gutter markers, including the pane's `p` promotion)
and `test-threads.lua` (the thread-pair model: promotion, the two
outboxes, the resolve cascade, agent diversion, gh pull matching).
Both are self-seeding (real sessions, threads through the real write
path) and **wipe the codeboomer database at the end**, so run them
with `XDG_DATA_HOME` redirected at an empty temporary directory:

```bash
mkdir -p /tmp/xdg-isolate/nvim
XDG_DATA_HOME=/tmp/xdg-isolate nvim --headless -u NONE \
  --cmd "set rtp^=$PWD" -c 'luafile test-sidebar.lua'
XDG_DATA_HOME=/tmp/xdg-isolate nvim --headless -u NONE \
  --cmd "set rtp^=$PWD" -c 'luafile test-threads.lua'
```

### Trusting the repo

You need to trust the repo for the plugin to compile your code. Open a fennel buffer, follow the prompt, press `v` to view and then run `:trust` in the empty buffer that Neovim opens.

## LLM assistance

- GLM 5.2

## License

MIT
