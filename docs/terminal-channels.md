# Terminal channels — talking to the harness without tmux

Design notes for the channel driver: Neovim terminal buffers as first-class
targets, alongside tmux panes, with the agent bridge riding the parent
session's RPC socket instead of a second headless editor.

## The three paths as they were

| Direction | Path | Cost |
|---|---|---|
| nvim → agent | `tmux.fnl`: `load-buffer` + `paste-buffer -p -r` + `send-keys Enter` | three synchronous `io.popen` shell-outs per message, quoting and buffer juggling |
| agent → nvim | `codeboomer-agent` shim → second headless nvim (`-u NONE`, plugin loaded) → sqlite | a whole editor per post; the live session learns about it only when a `CursorMoved`/`FocusGained` fires the DB refresh |

## The idea

Start the process as a Neovim job (`termopen`) in a terminal buffer, and use
the channel primitives for everything. Every tmux primitive has a native
twin — each of these was verified live before implementation:

| Concern | tmux | channel |
|---|---|---|
| spawn | `tmux new-window -d` | `termopen(argv, {cwd=…})` in a dedicated split |
| send | `paste-buffer -p` + `send-keys` | `chansend(chan, "\27[200~"..text.."\27[201~\r")` — bytes hit the pty master, so the bracketed-paste wrap behaves exactly like tmux's `-p` |
| list targets | `list-panes` | buffers carrying `b:terminal_job_id` |
| preview / last line | `capture-pane` scraping | `nvim_buf_get_lines` — structured, full scrollback |
| agent → nvim | shim → headless nvim → sqlite → polling | children inherit `$NVIM` (the parent's socket); `nvim --server "$NVIM" --remote-expr "v:lua.require('codeboomer.agent').rpc()"` posts into the **live** session, evented |

`vim.system` is the same job machinery one-shot — sessions are
just the long-lived, pty-attached form of it.

## Driver model

`tmux.fnl` and `channel.fnl` implement the same surface — `list-panes`,
`last-lines`, `send`, `spawn` — and every pane record carries a `:driver`
field (`:tmux` / `:channel`). `SetPane`'s picker merges both lists; sends
dispatch on the record's driver. tmux keeps working exactly as before; a
terminal buffer is simply another kind of pane.

- **Pane ids**: tmux panes are `%N`, terminal buffers `nN` (the buffer
  number) — unique in the merged picker, and the preview routes on the first
  character.
- **Picker preview** is one hybrid shell command: `n`-prefixed ids read the
  buffer through `nvim --server "$NVIM" --remote-expr` (a thin client, ~tens
  of ms, same order as `capture-pane`); anything else falls through to
  `tmux capture-pane`.
- **Records** reuse the tmux pane shape (`session-name`, `pane-id`,
  `pane-current-command`, …) so `pane-display` and the pick flow treat both
  alike. Channel panes say `nvim` for the session.

## The RPC bridge

When the agent is a child of the session that owns the review (a terminal
buffer started by `LaunchProcess`/`LaunchReviewer`, or any nvim job), `$NVIM`
points back at that session, and the generated `codeboomer-agent` shim takes
a fast path first:

1. `nvim --server "$NVIM" --remote-expr "v:lua.require('codeboomer.agent').rpc('<args b64>')"`
   runs the verb **inside the live editor** — same DB, same sqlite handle,
   no second process writing from the outside. (The arguments travel
   base64-encoded inside the expression: the thin client's environment
   never reaches the server, so the env var the headless path reads
   can't.)
2. A successful post fires the `CodeboomerAgentPosted` `User` autocmd, which
   the comments pane listens for — the thread shows up immediately, not on
   the next cursor move.
3. Any failure — dead socket, refused post, error inside `rpc()` — falls
   back to the headless run, which reports properly. Errors never surface
   as silent no-ops.

`help`/`-h`/`--help` still answer locally (through the headless path) so a
cold agent can discover the tool without a session.

A tmux-spawned agent has no `$NVIM` (the tmux server's environment wins), so
it keeps the headless bridge unchanged — one more reason the drivers
coexist.

## What tmux still gives

- **Lifetime**: nvim jobs die with nvim. Right semantics for agents this
  plugin launches; wrong for a REPL pane older than your editor. Pick those
  with `SetPane` as before.
- **Reach**: panes in other sessions, on other hosts (`send keys over ssh`
  is a standing todo item). A terminal buffer is local-only.

## Configuration

```lua
require("codeboomer").setup({
  spawning = { backend = "channel" },  -- default; "tmux" restores the old reviewer behavior
  prompting = {
    -- `terminal` (&shell), `pi` and `claude` ship as built-ins; an entry
    -- overrides a built-in by label, or appends a new label
    launch_processes = {
      { label = "pi", argv = { "pi", "--model", "sonnet" } },
    },
  },
})
```

- `LaunchProcess` picks an entry (picker when more than one) and starts it in
  a terminal buffer on the current work tree, tethering it as the pane. It is
  channel-only — tmux windows remain reachable through `LaunchReviewer`'s
  backend switch or by picking panes with `SetPane`.
- `TogglePane` collapses the selected pane's terminal out of the layout and
  brings it back — the job runs on through both (closing a terminal window
  only hides its buffer); the pane stays selected and sendable while hidden.
- `LaunchReviewer` defaults to the channel driver; `spawning.backend =
  "tmux"` restores the background tmux window.

## Test strategy

- Specs spawn real `sh` processes through the driver (a `cat` standing in
  for the harness), asserting the bytes the pty receives — bracketed paste
  included — and the spawned buffer's name, cwd and listing.
- The reviewer specs assert the composed prompt via an argv-capturing
  stand-in process instead of the tmux log.
- The shim's fast path is asserted on content (the `$NVIM` branch) and
  `rpc()`'s behavior, help, error fallback, and the fired autocmd.

## Future

- An agent that speaks msgpack-rpc directly (pi's harness could) may skip
  the `nvim` thin client and notify the socket itself — the bridge contract
  (`CodeboomerAgentPosted`) stays the same.
- `LaunchProcess` per-entry backend choice (`{ backend = "tmux" }`) if a
  long-lived watcher outliving nvim becomes a need.
