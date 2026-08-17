# compis.nvim

A Neovim plugin for sending text and commands to tmux panes. Written in [Fennel](https://fennel-lang.org/), compiled to Lua automatically via [nfnl](https://github.com/Olical/nfnl).

## Features

- Send text from Neovim to any tmux pane
- Fuzzy-finder interface (via fzf-lua) to select target panes
- Visual mode support — send code selections wrapped in context
- Bracketed-paste support for proper multi-line handling

## Installation

```lua
-- lazy.nvim
{
  "your-org/compis.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("compis").setup()
  end,
}
```

## Keybindings

The plugin sets up no default keybindings:
You can set up something like this

| Mode | Binding | Description |
|------|---------|-------------|
| Normal | `<leader>cs` | Send a message to the selected pane |
| Visual | `<leader>cs` | Send the selected text to the pane |
| Normal | `<leader>cp` | Pick a tmux pane to send messages to |

Disable or customize any binding in `setup()`:

```lua
require("compis").setup({
  -- Use different bindings
  send = "<leader>cs",
  send_visual = "<leader>cs",
  pane = "<leader>cp",

})
```

## Commands

### `:Compis SendKeys [message]`

Sends text to the tmux pane selected via `:Compis SetPane`.

- Without arguments, prompts for input
- With a message argument, sends it directly
- From visual mode, sends the selection wrapped in a code fence with context (file and line numbers)

```
:'<,'>Compis SendKeys what does this do
```

### `:Compis SetPane`

Opens fzf-lua to select a target tmux pane. Shows session, window, pane index, running command, and current mode.

### `:Compis ParseSessions` / `:Compis ParsePanes`

Debug commands that return parsed tmux state as Lua tables.

### `:Compis Compose`

(Reserved for future use)

## How it works

1. Select a pane with `<leader>cp` or `:Compis SetPane`
2. Send text with `<leader>cs` or `:Compis SendKeys`
3. For code selections, the plugin includes file path and line numbers in the message

The plugin uses tmux's bracketed-paste mode (`paste-buffer -p`) so multi-line text preserves line breaks in TUI applications.

## Configuration

```lua
require("compis").setup({
  -- Keybindings - set to false to disable
  send = "<leader>cs",      -- normal mode: send message
  send_visual = "<leader>cs", -- visual mode: send selection
  pane = "<leader>cp",      -- pick target pane
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
vim.opt.runtimepath:append("/path/to/compis.nvim")
require("compis").setup()
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
│   └── compis.lua      # registers the :Compis user command
├── fnl/
│   └── compis/
│       ├── init.fnl    # main module (setup, SendKeys, SetPane)
│       ├── config.fnl  # keymap defaults & setup
│       └── input.fnl   # floating input UI
└── lua/
    ├── compis/
    │   ├── init.lua    # ← compiled from fnl/compis/init.fnl
    │   ├── config.lua  # ← compiled from fnl/compis/config.fnl
    │   └── input.lua   # ← compiled from fnl/compis/input.fnl
    └── nfnl/            # embedded nfnl runtime (not hand-edited)
```

### Trusting the repo

You need to trust the repo for the plugin to compile your code. Open a fennel buffer, follow the prompt, press `v` to view and then run `:trust` in the empty buffer that Neovim opens.

## LLM assistance

- GLM 5.2

## License

MIT
