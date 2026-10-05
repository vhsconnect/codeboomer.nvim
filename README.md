# codeboomer.nvim

A Neovim plugin for sending text and commands to tmux panes. Useful for sending text blocks to a repl or an AI agent along with some comments or instructions. 

## Features

- Send text from Neovim to any tmux pane
- Fuzzy-finder interface (via fzf-lua) to select target panes, showing each pane's last output line and working directory, with a live content preview
- Visual mode support — send the selection as-is (`SendSelection`) or as context in a composed prompt (`SendPrompt`)
- Resend the last prompt (`SendLastPrompt`) without retyping it — the current selection or file is recomposed as context
- Annotation workflow — accumulate multiple code selections for review before sending
- **Branch sessions (`ResetSession`)** — annotations are grouped into one session per branch, created on the first annotation and resolved from the branch the buffer sits on — never picked (a detached HEAD has no branch, so no session). `ResetSession` deletes the branch's session with its threads and comments, the way to terminate a set of comments and start fresh
- **PR review (`Review`)** — review the PR's branch as you have it checked out, committed or not — the flow is always the same, simple annotation. `Review` picks a PR whose head is the checked-out branch, binds the branch's session to it (once — re-binding to another PR takes a `ResetSession`) and pulls its inline comments down as threads; `PostReview` pushes the threads you **promoted** (the pane's `p`) up as a pending review (a draft submitted on GitHub). No worktree is created and nothing is checked out — be on the branch you mean to review when you launch Neovim
- **Local/review thread halves** — every annotation starts as a local conversation with the agent (annotate, `a`-replies, agent answers via the shim); `p` in the comments pane promotes a thread: the shipping half is born with the final wording, anchored at the thread's own commit, after two refusals — the annotation must sit inside the PR's diff, and its code snapshot must still match the anchor commit's file content (lines that moved on after annotation can't resolve on GitHub). Nothing reaches `PostReview` without that deliberate step — agent chatter and your negotiation with it are structurally unshippable
- **Review comments pane** — a first-class side split that always shows exactly one thread, the current one: opening a repo whose branch session already has comments opens the pane straight away; resting the cursor inside a commented range shows that thread (both halves interleaved as one conversation), entering a file with threads shows its first, and `n`/`N` cycle through the session's threads in a loop — each hop landing the code window on the thread without leaving the pane; only source-file windows drive it — floats, terminals and plugin windows never open the pane or pull it into their tab; the pane keeps its thread when the cursor moves off every range or the buffer changes — window-navigate into it, where `r` replies on the review half (promoted threads and pulled ones), `a` replies to the agent, `p` promotes, `e` edits the promoted comment, `q` resolves and `n`/`N` step to the next/previous thread
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
| Normal + Visual | `<leader>cl` | `SendLastPrompt` — resend the last prompt; the current selection (or file) is recomposed as context |
| Visual | `<leader>cr` | `SendSelection` — send the selection to the pane as-is, then press Enter |
| Normal + Visual | `<leader>cc` | `AskOneOff` — run a one-off query; the answer is shown in a notification |
| Normal | `<leader>cp` | `SetPane` — pick a tmux pane to send messages to |
| Normal | `<leader>cS` | `ResetSession` — reset this branch's review session |
| Normal | `<leader>cR` | `Review` — pick a PR to review on the current checkout |
| Normal | `<leader>cP` | `PostReview` — push the promoted threads to the PR |
| Normal | `<leader>cL` | `PullReview` — pull the PR's inline comments into the session |
| Normal + Visual | `<leader>ca` | `Annotate` — add the selection (plus an optional note) to the query context; from normal mode, a whole-file comment |
| Normal | `<leader>cd` | `FlushWithDirective` — flush accumulated annotations with a directive |

Disable or customize any binding under `keybindings` in `setup()` (set to `false` to disable):

```lua
require("codeboomer").setup({
  keybindings = {
    send_prompt = "<leader>cs",
    send_last_prompt = "<leader>cl",
    send_selection = "<leader>cr",
    ask_one_off = "<leader>cc",
    flush_with_directive = "<leader>cd",
    pane = "<leader>cp",
    reset_session = "<leader>cS",
    review = "<leader>cR",
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
run. Every `gh` call — its arguments, the JSON payload sent up and the
response — is appended to `stdpath("log")/codeboomer-gh.log`, the place
to look when GitHub rejects a post. Off by default:

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

### `:Codeboomer SendLastPrompt`

Sends the most recent `SendPrompt` text again, without opening the input
UI — handy for retrying the same instruction against a fresh selection or
after the agent's context moved on.

- The context header is recomposed from the current range: with a visual
  range the selection is included, without one the current file is used
- Requires a pane (picked first if none is selected)
- If no prompt was sent yet this session, a warning notification is shown
  instead of sending

```
:'<,'>Codeboomer SendLastPrompt
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

Opens a PR review on the branch you already have checked out:
nothing is fetched, no worktree is created, nothing is checked out or
made read-only — you annotate the code exactly as it sits in your
working tree, committed or not. To review a particular commit, create
a branch for it first: sessions are tied to branches, and a detached
HEAD has none.

- Without an argument an fzf picker over `gh pr list` opens — choosing
  a PR *is* opening its review; with a number the picker is skipped.
  Requires `gh` and a GitHub-hosted remote
- The checked-out branch must be the PR's: named after its head
  branch, tracking it or the PR's `refs/pull/N/head` (as
  `gh pr checkout -b` and fork PRs set up), or sitting on its head
  commit — otherwise `Review` refuses and names the branch to check out
- The branch's session is found (or created) and bound to the PR
  (`pr_number`): `Annotate`, the comments pane and
  `FlushWithDirective` all follow the branch; re-opening the same PR
  reuses its threads. A session binds once: reviewing another PR from
  the same branch (a re-opened PR, a second base) is refused until
  `:Codeboomer ResetSession`, since the session's threads belong to
  the first PR
- The PR's inline comments come down as threads (`:Codeboomer
  PullReview` refreshes — idempotent by GitHub comment id)
- The PR's diff (`gh pr diff`) is loaded so promotion (`p`) and
  `PostReview` can refuse threads that fall outside the diff before
  GitHub does — in the background when `Review` opens, and on demand
  the first time `p` or `PostReview` needs it in a Neovim that has
  not run `Review` yet (after a restart); when the diff can't be
  loaded the check steps aside and GitHub's own rejection surfaces at
  post time
- Threads anchor to the commit you had checked out when you annotated
  — be on the branch you mean to review before you start
- The review-comments pane opens straight away when the branch's
  session already has comments (opening the repo is enough, whatever
  buffer nvim starts in) and always shows exactly ONE thread — the
  current one — whatever the main buffer is: resting the cursor
  (~100 ms) inside a commented range shows that thread's comments
  (overlapping ranges pick the earliest), entering a file with
  threads shows its first, and `n`/`N` cycle through the session's
  threads without leaving the pane. The thread renders as one block,
  its header tinted in the thread's color, every comment labeled
  `[source] name`, with a dimmed keymap footer under the block.
  Moving off every range — or into a threadless file — keeps the
  current thread on screen: pane and cursor are not strictly tied.
  `:q` closes the pane and the next rest, threaded file enter or
  repo open reopens it. A cursor completely still for ~5 s
  re-queries the database in one pass — a trailing debounce every
  cursor move restarts, so at most one query per rest — and the
  pane re-renders from whatever came back wherever it sits (agent
  replies arrive from outside the editor): no landing back on the
  thread's line to see an update. Window-navigate into it
  (`<C-w> w`); buffer-local keys act on the thread on screen:

| Key | Action |
|-----|--------|
| `r` | Reply on the **review half** — the half that ships. Only exists once the thread is promoted (`p`) or pulled from GitHub; unpromoted threads refuse with a pointer to `p`, so nothing reaches the posting outbox by accident |
| `a` | Reply to the **agent** — the local conversation half (created on demand for pulled threads). Your side of any discussion with the agent; never ships |
| `p` | **Promote** — open the compose input prefilled with the annotation's wording and create the review half with the final text. A *virgin* thread (one user comment, nothing from the agent) promotes as-is with no input. Refuses when the branch's session is not bound to a PR (run `Review` first), and when the range falls outside the PR diff |
| `e` | Edit the promoted comment in place (the oldest still-unposted one) through the same prefilled input |
| `q` | Resolve the thread — resolved threads are treated as soft-deleted: both halves of the pair leave the pane and both outboxes; the pane hands the screen to whatever covers the cursor, else the next thread, right away |
| `n` | Next thread — cycle through the session's threads in a loop (wrapping at both ends, `N` goes back); each hop lands the code window's buffer and cursor on the thread (the line flashes) without taking focus off the pane |

- `:Codeboomer PostReview` pushes your **promoted** threads up as a
  pending review — a draft you submit on GitHub (comment / approve /
  request changes), so nothing reaches the author until you do. Only
  user comments of review halves ever ship: agent-authored comments
  and the local conversation with the agent stay on your machine

```vim
:Codeboomer Review 42
```

### `:Codeboomer ResetSession`

Terminates the current branch's set of comments. Sessions are tied to
branches — one per repository and branch, resolved from the buffer
you are in — so there is nothing to pick; this is the one way to start
over.

A session is keyed by the branch's *name*: renaming a branch leaves
its session behind (the new name starts a fresh one), and a deleted
branch whose name is later reused picks its old session — and PR
binding — back up. `ResetSession` is the way out of either.

The branch's session is **deleted for good**, with its threads and
comments; there is no undo. Ids are never reused, so an agent
answering a deleted thread is refused rather than landing on a newer
one. The comments pane reloads empty, and the next annotation starts
a fresh session — its PR binding, if any, is gone with the old one,
so run `Review` again to re-bind and pull the PR's comments into the
fresh session. Warns when the branch has no session.

### `:Codeboomer PostReview`

Pushes the branch session's **promoted** threads — the review halves
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
  pending review per anchor commit (each thread's own commit), so
  every inline comment resolves against the exact diff it was written
  on
- GitHub allows one pending review per user and PR: posting again
  while a draft is unsubmitted fails with a 422 — submit or discard
  the draft on GitHub first
- Threads whose range falls outside the PR's diff are refused
  locally first (the same check runs at promotion time) — GitHub
  would reject them anyway
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

Imports the PR's current inline comments into the branch's PR-bound
session as threads (warns when the session is not bound — run
`Review` first) — idempotent by GitHub comment id (re-pulls add only what's
new), replies joined to their threads, and comments GitHub marks
outdated anchored best-effort at their original line with an
`outdated` flag in the thread header. Whole-file PR comments
(`subject_type = file`) import as `type = file` threads — no lines,
never flagged outdated. A comment that is one of your
own posted ones (`PostReview` + submitted draft) comes home by
stamping its gh id onto the local review half instead of seeding a
duplicate thread. `:Codeboomer Review` runs this automatically after
opening; the comments pane reloads on arrival.

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
- The review session is the current branch's: found on write, created on the branch's first annotation (see `:Codeboomer ResetSession` to start over)
- Annotations are stored in the review session's database — the single store — each as its own **local conversation thread** (`kind = local`): tracked as not-yet-sent (agent) and invisible to `PostReview` until promoted in the comments pane (`p`). They are included in the next `:Codeboomer FlushWithDirective` call until sent
- The comments pane follows along in any session — it opens on repo
  open when the branch's session has comments, and always shows one
  thread: resting the cursor inside a commented range shows that
  thread's comments, entering a file with threads shows its first,
  and `n` cycles from there; file-level threads carry no lines, so
  the pane shows them with a `file` position instead of a line range
- Refuses on a detached HEAD — check out a branch first
- Empty notes are ignored

```
:'<,'>Codeboomer Annotate
```

### `:Codeboomer FlushWithDirective`

> [!warn] **Tentative API** — This command is experimental and subject to change in future versions.

Opens fzf to select a pre-defined directive, then sends it along with all unsent annotations from `:Codeboomer Annotate` (threads resolved before the flush are soft-deleted and never ship).

- Requires a pane to be selected first via `:Codeboomer SetPane`
- Select from a list of pre-defined directives (see Configuration below for customizing)
- After sending, the delivered annotations are marked `sent` in the database — they persist but are never re-sent; annotations survive restarts because the database is the only outbox
- Each message carries one **whole thread**: the header (`regarding <file> lines X to Y (thread N)`), the annotated code, and the full conversation — every comment author-labeled (`[user] vhs: …`, `[agent] agent: …`, `[github] reviewer: …`), so a reply flushed to a pulled thread ships the GitHub reviewer's words along and a re-asked thread ships the agent's earlier answers. Several unsent comments of one thread ship as one conversation, not one copy each
- The payload ends with a reply instruction pointing at the generated `codeboomer-agent` shim — the agent answers each thread with `codeboomer-agent reply <thread-id> <text>`, which appends an agent comment to that thread in the database (visible in the comments pane on its next reload)
- The shim is also self-documenting: `codeboomer-agent help` (equally `-h`, `--help`, or no arguments at all) prints its full usage, so an agent that's only been handed the path can work out how to use it without any of the above spelled out in a prompt

```vim
:Codeboomer FlushWithDirective
```

## How it works

### Basic workflow

1. Select a pane with `<leader>cp` or `:Codeboomer SetPane`
2. Send a prompt with `<leader>cs` (`:Codeboomer SendPrompt`), or send the selection as-is with `<leader>cr` (`:Codeboomer SendSelection`) — resend the last prompt with `<leader>cl` (`:Codeboomer SendLastPrompt`)

### Annotation workflow

For more complex queries, you can build up context across multiple selections:

1. Select a pane with `<leader>cp`
2. Select code sections and run `<leader>ca` (or `:Codeboomer Annotate`) to add annotations to your query
3. When ready, run `<leader>cd` (or `:Codeboomer FlushWithDirective`) to send your directive along with all unsent annotations — the database is the outbox, so annotations survive restarts
4. The agent answers each thread back with `codeboomer-agent reply <thread-id> <text>` (the instruction is included in the payload); replies land in the same threads — for a pulled thread they join a local twin created on demand — and show up in the comments pane, where you can also answer threads yourself — window-navigate into the pane, then `a` to talk to the agent, `r` to reply on the review half, `q` to resolve

A review session is created for the branch on its first annotation;
annotations, flushes and the comments pane all follow the branch you
are on. `:Codeboomer ResetSession` (`<leader>cS`) terminates it — the
next annotation starts fresh.

### PR review workflow (local)

1. Check out the branch you mean to review and launch Neovim on it
2. `<leader>cR` (`:Codeboomer Review`) — pick a PR; the branch's
   session is bound to it, its inline comments come down as threads,
   and the comments pane opens with the session's first thread
3. Annotate selections with `<leader>ca` as usual — threads show in
   the comments pane: `a` discusses with the agent, `q` resolves,
   `n` hops to the next thread
4. `p` promotes the survivors: the compose input opens prefilled with
   the annotation's wording (virgin threads promote as-is), the review
   half anchors at the thread's own commit, and the header gains
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

The same pipeline is available from the shell as Babashka tasks:

```bash
nix develop -c bb format  # fnlfmt every Fennel source in the repo, in place
nix develop -c bb compile # compile every fnl/ source to lua/ (byte-identical to :NfnlCompileAllFiles)
nix develop -c bb build   # format, then compile
```

`compile` drives the Fennel compiler vendored under `lua/nfnl/` (via
`scripts/compile.lua`), so it runs headlessly with no plugins on the
runtimepath; `format` uses `fnlfmt` from `PATH` when available and falls
back to `nix run nixpkgs#fnlfmt` otherwise.

### nfnl commands

These are available automatically when nfnl is loaded (no extra config needed):

| Command | Description |
|---------|-------------|
| `:NfnlCompileFile` | Compile the current (or given) `.fnl` file to Lua |
| `:NfnlCompileAllFiles` | Compile every `.fnl` file in the project |
| `:NfnlFindOrphans` | List `.lua` files with no matching `.fnl` source |
| `:NfnlDeleteOrphans` | Delete those orphan `.lua` files |
| `:NfnlFile` | Execute a compiled `.lua` file from disk |

### Hot reload

`dev/reload.fnl` reloads the plugin inside the running Neovim session, via Conjure. Conjure's Fennel client evaluates in-process — the same Lua instance the plugin runs in — so an evaluated form can purge `package.loaded` and re-require everything. The file lives outside `fnl/` on purpose: nfnl's `source-file-patterns` only build `fnl/**`, so nothing in it is compiled into `lua/` or ships with the plugin.

Two functions in it:

- `(reload)` — close the shared sqlite handle, drop every `codeboomer.*` module from the require cache, re-require and re-run `setup()`
- `(setup)` — re-apply opts to the live modules only; no purge, no recompile — that's the whole loop for iterating on configuration

The loop, no restart:

1. edit `fnl/codeboomer/*.fnl`
2. `:NfnlCompileAllFiles` — compiles from disk, so stale open buffers don't matter
3. evaluate the whole file once (Conjure's eval-buffer) — the trailing `(reload)` runs in the same chunk as the definitions; from then on re-evaluating just that `(reload)` form is enough — the entry points are globals, since locals don't survive between Conjure evals

Setup opts come from the `dev-opts` table at the top of the file (mirroring `./test-codeboomer`); set it to `nil` to instead re-use the live merged config from the previous `setup()`. The `:Codeboomer` command survives reloads untouched — `plugin/codeboomer.lua`'s handlers require lazily, at call time. After a reload the chosen tmux pane is forgotten (re-pick with `<leader>cp`), and an open comments pane should be closed first: the fresh sidebar module has no reference to the old window and would open a duplicate.

### Setting up a dev environment

For testing the repo's copy against your **regular** Neovim config (it is prepended to the runtimepath, so it shadows any installed version — rebuild artifacts with `nfnl` first), use `./test-codeboomer`. It requires `CODEBOOMER_PATH` to point at the plugin directory and wires up the full keymap set (`<leader>cs`, `<leader>cl`, `<leader>cr`, `<leader>cc`, `<leader>cd`, `<leader>cp`, `<leader>cS`, `<leader>cR`, `<leader>cP`, `<leader>cL`, `<leader>ca`). Extra arguments pass through to nvim, so you can land straight in a review:

```bash
CODEBOOMER_PATH=$PWD ./test-codeboomer                          # plain launch
CODEBOOMER_PATH=$PWD ./test-codeboomer -c 'Codeboomer Review'    # opens the PR picker
CODEBOOMER_PATH=$PWD ./test-codeboomer -c 'Codeboomer Review 42' # straight to PR 42
```

(The review commands need `gh` authentication and network — the PR list, its inline comments and its diff are fetched once the picker resolves.)

The test suite runs on a vendored copy of
[nvim-test](https://github.com/lewis6991/nvim-test) (`test/vendor/nvim-test`,
busted driving a fresh embedded Neovim per test). The flake's dev shell
provides busted, a pinned Neovim and sqlite.lua. Each test gets its own
scratch git repo and `XDG_DATA_HOME` under `scratch/`, so your real
codeboomer database is never touched:

```bash
nix develop -c bb test                # every spec under test/
nix develop -c bb test --filter <pattern> # only tests whose name matches
```

The test tree mirrors the plugin's `fnl/` → `lua/` split:

- `test/fnl/` holds the Fennel sources (`*_spec.fnl`, plus
  `cb_helpers.fnl` with the shared helpers — `clear`, `setup-test-repo`,
  `setup-codeboomer`, `module` for calling plugin functions inside the
  child Neovim — and the `fixtures` table)
- `test/lua/` is compiler output (gitignored), rebuilt from scratch by
  `scripts/compile-tests.lua` on every `make test` with the Fennel
  embedded under `lua/nfnl`, line-correlated so failures point at the
  Fennel line
- `test/vendor/nvim-test/` is the vendored test framework

### Schema changes

There are no migrations. The database lives at
`stdpath("data")/codeboomer-db-v<N>`, where `N` is `db-version` in
`fnl/codeboomer/singleton.fnl`. Any schema change bumps it: the next
start opens a new, empty file, and earlier versions' files stay on
disk untouched (delete them by hand once you no longer need them).

### Trusting the repo

You need to trust the repo for the plugin to compile your code. Open a fennel buffer, follow the prompt, press `v` to view and then run `:trust` in the empty buffer that Neovim opens.

## LLM assistance

- GLM 5.2

## License

MIT
