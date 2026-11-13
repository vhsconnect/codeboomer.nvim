
## What it does

- Send annotated code snippets to a seperate process or tmux pane - read agent harnass - to communicate with it.
- Annotate Multiple files and send them with a specific/custom directive to a different process when you're done.
- Keep track of various annotations/comments/conversations in a sidepane view.
- The sidepane tracks conversations/comments. You can jump through comments quickly, dimiss some when you're done
- conversations are between you and the agent or you and the PR reviewer on github. You can promote a conversation with an agent and cherry pick what to send to github as PR comment. You can also chat about a PR comment with your agent before responding on github - or promoting a response to github.
- You can start a code reviewing session by opening a github PR and load all its comments into the sidebar while you review it.
- You can send code to a repl for reads.

## How it works

Codeboomer is designed to let you drive your ai harnass and your review workflow from within neovim. It does so in a variety of ways but in summary it allows for 2 way comunication with a different process - either through tmux panes or an embedded terminal. The proess calls neovim back by calling the codeboomer shim through neovim itself with `--headless`. 


## Requirements

Neovim, [fzf-lua](https://github.com/ibhagwan/fzf-lua), [sqlite.lua](https://github.com/kkharji/sqlite.lua) (needs system `libsqlite3`), and [tmux](https://github.com/tmux/tmux) for tmux panes. PR features additionally need `gh` authenticated against a GitHub remote.

## Installation and Configuration

```lua
-- lazy.nvim
{
  "vhsconnect/codeboomer.nvim",
  lazy = false, -- keeps the agent bridge and sidebar hooks live for
                -- agent replies arriving from outside the editor
  dependencies = { "ibhagwan/fzf-lua", "kkharji/sqlite.lua" },
  config = function()
    require("codeboomer").setup({})
  end,
}
```

`setup()` sets no default keybindings; configure your own:

```lua
require("codeboomer").setup({
  keybindings = {
    send_prompt = "<leader>cs",         -- prompt (selection included in visual mode)
    send_last_prompt = "<leader>cl",    -- resend last prompt
    send_selection = "<leader>cr",      -- send selection as-is (visual)
    annotate = "<leader>ca",            -- add selection to the session
    flush_with_directive = "<leader>cd",-- send annotations with a directive
    pane = "<leader>cp",                -- pick a target pane
    ask_one_off = "<leader>cc",         -- one-shot query
    launch_reviewer = "<leader>cA",     -- spawn a review agent
    launch_process = "<leader>cT",      -- spawn a process pane
    pane_toggle = "<leader>ct",         -- collapse/restore the pane split
    sidebar_toggle = "<leader>cb",      -- collapse/restore the comments pane
    reset_session = "<leader>cS",       -- delete this branch's session
    review = "<leader>cR",              -- open a PR review
    post_review = "<leader>cP",         -- push promoted threads to GitHub
    pull_review = "<leader>cL",         -- refresh the PR's comments
  },
  prompting = {
    -- a label matching a built-in overrides it; new labels append
    directives = {
      { label = "Explain", text = "Explain the selected code. No changes." },
    },
    one_off_commands = {
      { label = "claude-code (haiku)",
        argv = { "claude", "--model", "haiku", "--output-format", "json", "-p" } },
      { label = "Local",
        argv = { "ollama", "run", "qwen2.5-coder" },
        timeout = 300000 },
    },
    review_agents = {
      { label = "claude", argv = { "claude", "--dangerously-skip-permissions" } },
      { label = "pi", argv = { "pi" } },
    },
    launch_processes = {
      { label = "pi", argv = { "pi" } },
      { label = "claude", argv = { "claude", "--dangerously-skip-permissions" } },
    },
  },
})
```

Set any binding to `false` to disable it. `prompting.directives` customizes the flush directives (built-ins: converse only, converse + change, change, change + commit).

## Usage

**Sending** — pick a pane with `<leader>cp`, then send a prompt (`<leader>cs`), resend it (`<leader>cl`), or paste the selection as-is (`<leader>cr`).

**Annotating** — annotate selections with `<leader>ca` as you read, then `<leader>cd` to pick a directive and send everything in one message. The agent answers each thread back into the comments pane; discuss with `a`, resolve with `q`. Sessions are tied to your current branch; `<leader>cS` starts over.

**Reviewing a PR** — check out the branch, run `<leader>cR` and pick the PR; its inline comments arrive as threads. Annotate as usual, promote keepers with `p`, and `<leader>cP` posts them as a pending review to submit on GitHub.

All commands are also available as `:Codeboomer <Name>` (e.g. `:Codeboomer Review 42`).

##### LLM assisted

GLM 5.2

## Hacking on codeboomer

The plugin is written in Fennel (`fnl/`) and compiled to the checked-in `lua/` with [nfnl](https://github.com/Olical/nfnl) — treat `lua/` as build output, never edit it by hand. `nix develop` drops you into a shell with babashka, fnlfmt, busted and Neovim wired up (falls back to `nix run` for the tools if you skip it):

- `bb build` — format every Fennel source with fnlfmt, then compile `fnl/` to `lua/`
- `bb test` — run the busted suite (`bb test --filter pattern` to narrow)
- `./test-codeboomer` — scratch Neovim with the plugin loaded; extra args pass through to nvim
- `dev/reload.fnl` — Conjure hot-reload loop: eval the buffer once, then re-eval `(reload)` to pick up edits without restarting

Specs are Fennel too, in `test/fnl/` (helpers in `cb_helpers.fnl`); `bb test` compiles them alongside the plugin first. For fennel-ls, `flsproject.fnl` already sets the fennel/macro paths and test globals.

## License

MIT
