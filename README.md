# varubrev.nvim

A Neovim plugin for sending text and commands to tmux panes. Written in [Fennel](https://fennel-lang.org/), compiled to Lua automatically via [nfnl](https://github.com/Olical/nfnl).

## Features

- Send text from Neovim to any tmux pane
- Fuzzy-finder interface (via fzf-lua) to select target panes
- Visual mode support — send code selections wrapped in context
- Annotation workflow — accumulate multiple code selections for review before sending
- Bracketed-paste support for proper multi-line handling

## Installation

```lua
-- lazy.nvim
{
  "vhsconnect/varubrev.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("varubrev").setup({
      -- Optional: customize keybindings (set to false to disable)
      pane = "<leader>cp",        -- pick a tmux pane
      send = "<leader>cs",        -- send text to pane
    })
  end,
}
```

## Keybindings

The plugin sets up no default keybindings:
You can set up something like this

| Mode | Binding | Description |
|------|---------|-------------|
| Normal | `<leader>cs` | Send a message to the selected pane |
| Visual | `<leader>cs` | Send the selection to the pane |
| Visual | `<leader>cc` | Send a one-off query to Claude (no session) |
| Normal | `<leader>cp` | Pick a tmux pane to send messages to |
| Normal | `<leader>ca` | Annotate text (adds to query context) |
| Visual | `<leader>ca` | Annotate selection (adds to query context) |
| Normal | `<leader>cd` | Send with directive (includes accumulated annotations) |

Disable or customize any binding in `setup()`:

```lua
require("varubrev").setup({
  -- Use different bindings (set to false to disable)
  send = "<leader>cs",
  send_visual = "<leader>cs",
  send_visualOO = "<leader>cc",
  pane = "<leader>cp",
  annotate = "<leader>ca",
  send_with_directive = "<leader>cd",
})
```

## Commands

### `:Varubrev SendKeys [message]`

Sends text to the tmux pane selected via `:Varubrev SetPane`.

- Without arguments, prompts for input
- With a message argument, sends it directly
- From visual mode, sends the selection wrapped in a code fence with context (file and line numbers)

```
:'<,'>Varubrev SendKeys what does this do
```

### `:Varubrev SetPane`

Opens fzf-lua to select a target tmux pane. Shows session, window, pane index, running command, and current mode.

### `:Varubrev SendKeysOO`

Runs a **one-shot** Claude Code query — no tmux pane and no session needed:

```
:'<,'>Varubrev SendKeysOO
```

Opens the same input UI as `SendKeys` (a visual selection is included as context, with file and line numbers), then runs `claude-code -p` through `nix run` and shows the answer in a notification when it finishes.

- The input submits on `<CR>` and closes itself — `<C-j>` (insert mode) or `o` (normal mode) if you need a newline
- The prompt is passed as an argv vector via `vim.system`, so quotes, `$`, backticks and newlines in your message are never interpreted by a shell
- Runs asynchronously with a 60s timeout — the editor never freezes while the LLM thinks
- Failures surface the exit code and stderr in an `ERROR` notification

### `:Varubrev Annotate`

Adds the current selection to an accumulated query context. Use this to annotate multiple code sections before sending a directive.

- Requires a pane to be selected first via `:Varubrev SetPane`
- The selection is stored and will be included in the next `:Varubrev SendWithDirective` call

```
:'<,'>Varubrev Annotate
```

### `:Varubrev SendWithDirective`

> [!warn] **Tentative API** — This command is experimental and subject to change in future versions.

Sends your message along with all previously accumulated annotations from `:Varubrev Annotate`.

- Requires a pane to be selected first via `:Varubrev SetPane`
- Useful for providing multiple code sections as context before asking a question
- After sending, the annotation context is preserved for additional queries

```vim
:Varubrev SendWithDirective
```

### `:Varubrev ParseSessions` / `:Varubrev ParsePanes`

Debug commands that return parsed tmux state as Lua tables.

### `:Varubrev Compose`

(Reserved for future use)

## How it works

### Basic workflow

1. Select a pane with `<leader>cp` or `:Varubrev SetPane`
2. Send text with `<leader>cs` or `:Varubrev SendKeys`
3. For code selections, the plugin includes file path and line numbers in the message

### Annotation workflow

For more complex queries, you can build up context across multiple selections:

1. Select a pane with `<leader>cp`
2. Select code sections and run `<leader>ca` (or `:Varubrev Annotate`) to add annotations to your query
3. When ready, run `<leader>cd` (or `:Varubrev SendWithDirective`) to send your directive along with all accumulated annotations

This is useful for giving the LLM multiple code sections to consider before asking your question.

The plugin uses tmux's bracketed-paste mode (`paste-buffer -p`) so multi-line text preserves line breaks in TUI applications.

## Configuration

```lua
require("varubrev").setup({
  -- Keybindings - set to false to disable
  send = "<leader>cs",              -- normal mode: send message
  send_visual = "<leader>cs",       -- visual mode: send selection
  send_visualOO = "<leader>cc",     -- visual mode: one-off Claude query
  pane = "<leader>cp",              -- pick target pane
  annotate = "<leader>ca",          -- annotate text/selection (adds to context)
  send_with_directive = "<leader>cd", -- send with accumulated annotations
})
```

## Development

This plugin is written in **Fennel** and compiled to Lua using **nfnl** (embedded directly in the repo under `lua/nfnl/`).

### How the build works

1. You edit `.fnl` files under `fnl/`.
2. **nfnl** watches for `BufWritePost` on `.fnl` files and auto-compiles them to `.lua` under `lua/`.
3. The `.lua` files are never hand-edited — they are generated and contain an `[nfnl]` header comment for protection.

There is no separate build step. Save a `.fnl` file and the corresponding `.lua` is recompiled instantly.

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

To develop on this plugin without installing it into your main Neovim config, use `dev.lua`:

```lua
-- dev.lua  (run with: nvim -u dev.lua)
vim.opt.runtimepath:append("/path/to/varubrev.nvim")
require("varubrev").setup()
```

**Update the path** in `dev.lua` to point at your local clone, then launch:

```bash
nvim -u dev.lua
```

This gives you an isolated Neovim instance with the plugin loaded, nfnl active, and auto-compilation working — write any `.fnl` file and the corresponding `.lua` updates immediately.

### Project structure

```
.
├── .nfnl.fnl          # nfnl configuration (compiler options, macros, orphan detection)
├── dev.lua             # dev launcher (nvim -u dev.lua)
├── plugin/
│   └── varubrev.lua    # registers the :Varubrev user command
├── fnl/
│   └── varubrev/
│       ├── init.fnl    # main module (setup, SendKeys, SetPane)
│       ├── config.fnl  # keymap defaults & setup
│       └── input.fnl   # floating input UI
└── lua/
    ├── varubrev/
    │   ├── init.lua    # ← compiled from fnl/varubrev/init.fnl
    │   ├── config.lua  # ← compiled from fnl/varubrev/config.fnl
    │   └── input.lua   # ← compiled from fnl/varubrev/input.fnl
    └── nfnl/            # embedded nfnl runtime (not hand-edited)
```

### Trusting the repo

You need to trust the repo for the plugin to compile your code. Open a fennel buffer, follow the prompt, press `v` to view and then run `:trust` in the empty buffer that Neovim opens.

## LLM assistance

- GLM 5.2
- Claude Opus 5 (claude-opus-5[1m])

## License

MIT
