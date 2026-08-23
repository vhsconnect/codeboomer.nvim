# varubrev.nvim

A Neovim plugin for sending text and commands to tmux panes. Written in [Fennel](https://fennel-lang.org/), compiled to Lua automatically via [nfnl](https://github.com/Olical/nfnl).

## Features

- Send text from Neovim to any tmux pane
- Fuzzy-finder interface (via fzf-lua) to select target panes
- Visual mode support — send code selections wrapped in context
- Annotation workflow — accumulate multiple code selections for review before sending
- Bracketed-paste support for proper multi-line handling
- **One-off query mode** — spawn a single process for a quick task without maintaining a session or requiring a tmux pane (useful for quick questions, single commands, or testing without context overhead)

## Installation

```lua
-- lazy.nvim
{
  "vhsconnect/varubrev.nvim",
  dependencies = { "ibhagwan/fzf-lua" },
  config = function()
    require("varubrev").setup({
      -- Optional: customize keybindings (set to false to disable)
      keybindings = {
        pane = "<leader>cp",        -- pick a tmux pane
        send = "<leader>cs",        -- send text to pane
      },
    })
  end,
}
```

## Configuration

### Keybindings

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

Disable or customize any binding under `keybindings` in `setup()` (set to `false` to disable):

```lua
require("varubrev").setup({
  keybindings = {
    send = "<leader>cs",
    send_visual = "<leader>cs",
    send_visualOO = "<leader>cc",
    pane = "<leader>cp",
    annotate = "<leader>ca",
    send_with_directive = "<leader>cd",
  },
})
```

### Prompting

`<leader>cd` (`:Varubrev SendWithDirective`) picks a directive from a
fzf-lua menu — by default the two built-ins, `Review - converse` and
`Review - execute`. Pass your own list under `prompting.directives` in
`setup()` to add to or override it:

```lua
require("varubrev").setup({
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
keeps
the built-ins as-is.

`prompting.one_off_command` controls how `<leader>cc` (`:Varubrev SendKeysOO`)
runs its one-shot query: a static argv list. The composed prompt is appended
as the final argument when the command runs. When unset, it defaults to:

```lua
require("varubrev").setup({
  prompting = {
    one_off_command = {
      "claude", "-p", "--output-format", "json", "--permission-mode", "acceptEdits",
    },
  },
})
```

Point it at whatever the machine at hand provides — a plain binary, a
container wrapper, a nix flake invocation, … Output that is JSON with a
`result` field is shown as just the result; anything else is displayed raw.

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

Runs a **one-shot** query — spawns a single process for a quick task without maintaining a session or requiring a tmux pane:

```
:'<,'>Varubrev SendKeysOO
```

**When to use one-off mode:**
- Quick questions or single commands that don't require conversational context
- Testing or experimentation without session overhead
- Running isolated tasks where you want a clean slate each time
- Situations where you don't have or need a tmux pane running

**How it works:**
Opens the same input UI as `SendKeys` (a visual selection is included as context, with file and line numbers), then spawns a fresh process for your query and shows the answer in a notification when it finishes.

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

Opens fzf to select a pre-defined directive, then sends it along with all previously accumulated annotations from `:Varubrev Annotate`.

- Requires a pane to be selected first via `:Varubrev SetPane`
- Select from a list of pre-defined directives (see Configuration below for customizing)
- After sending, the annotation context is preserved for additional queries

```vim
:Varubrev SendWithDirective
```

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

For testing the repo's copy against your **regular** Neovim config (it is prepended to the runtimepath, so it shadows any installed version — rebuild artifacts with `nfnl` first), use `./test-varu`. It requires `VARUBREV_PATH` to point at the plugin directory and wires up the full keymap set (`<leader>cs`, `<leader>cc`, `<leader>cd`, `<leader>cp`, `<leader>ca`):

```bash
VARUBREV_PATH=$PWD ./test-varu
```

### Project structure

```
.
├── .nfnl.fnl            # nfnl configuration (compiler options, macros, orphan detection)
├── dev.lua               # dev launcher (nvim -u dev.lua)
├── test-varu             # test script for local development
├── test-input.lua        # test script for input UI
├── .envrc                # direnv configuration
├── .stylua.toml          # Lua styling configuration
├── plugin/
│   └── varubrev.lua      # registers the :Varubrev user command
├── ftplugin/
│   └── fennel.lua        # Fennel filetype plugin
├── fnl/
│   ├── .nfnl.fnl         # local nfnl configuration
│   ├── test.fnl          # test utilities
│   └── varubrev/
│       ├── init.fnl      # main module (setup, SendKeys, SetPane)
│       ├── config.fnl    # keymap defaults & setup
│       ├── directives.fnl # directive definitions and handling
│       └── input.fnl     # floating input UI
└── lua/
    ├── test.lua          # compiled test utilities
    ├── nfnl/
    │   └── nfnl/
    │       └── fennel.lua # embedded Fennel runtime
    └── varubrev/
        ├── init.lua      # ← compiled from fnl/varubrev/init.fnl
        ├── config.lua    # ← compiled from fnl/varubrev/config.fnl
        ├── directives.lua # ← compiled from fnl/varubrev/directives.fnl
        └── input.lua     # ← compiled from fnl/varubrev/input.fnl
```

### Trusting the repo

You need to trust the repo for the plugin to compile your code. Open a fennel buffer, follow the prompt, press `v` to view and then run `:trust` in the empty buffer that Neovim opens.

## LLM assistance

- GLM 5.2

## License

MIT
