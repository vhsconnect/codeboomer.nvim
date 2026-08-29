# codeboomer.nvim

A Neovim plugin for sending text and commands to tmux panes. Useful for sending text blocks to an AI agent along with some comments or instructions.

## Features

- Send text from Neovim to any tmux pane
- Fuzzy-finder interface (via fzf-lua) to select target panes
- Visual mode support — send the selection as-is (`SendSelection`) or as context in a composed prompt (`SendPrompt`)
- Annotation workflow — accumulate multiple code selections for review before sending
- Bracketed-paste support for proper multi-line handling
- **One-off queries (`AskOneOff`)** — spawn a single process for a quick task without maintaining a session or requiring a tmux pane (useful for quick questions, single commands, or testing without context overhead)

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

The plugin sets up no default keybindings:
You can set up something like this

| Mode | Binding | Description |
|------|---------|-------------|
| Normal + Visual | `<leader>cs` | `SendPrompt` — open the prompt; the selection is included as context when invoked visually |
| Visual | `<leader>cr` | `SendSelection` — send the selection to the pane as-is, then press Enter |
| Normal + Visual | `<leader>cc` | `AskOneOff` — run a one-off query; the answer is shown in a notification |
| Normal | `<leader>cp` | `SetPane` — pick a tmux pane to send messages to |
| Visual | `<leader>ca` | `Annotate` — add the selection (plus an optional note) to the query context |
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
keeps
the built-ins as-is.

`prompting.one_off_command` controls how `<leader>cc` (`:Codeboomer AskOneOff`)
runs its one-shot query: a static argv list. The composed prompt is appended
as the final argument when the command runs. When unset, it defaults to:

```lua
require("codeboomer").setup({
  prompting = {
    one_off_command = {
      "claude-code", "--model", "haiku", "--output-format", "json",
      "--permission-mode", "acceptEdits", "-p",
    },
  },
})
```

Point it at whatever the machine at hand provides — a plain binary, a
container wrapper, a nix flake invocation, … Output that is JSON with a
`result` field is shown as just the result; anything else is displayed raw.

## Commands

### `:Codeboomer SendPrompt`

Opens the input UI and sends the composed message to the selected pane.

- With a visual range, the selection is included as context (`regarding <file> lines X to Y`), followed by the typed text
- Without a range, only the typed text is sent

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

Opens fzf-lua to select a target tmux pane. Shows session, window, pane index, running command, and current mode.

### `:Codeboomer AskOneOff`

Runs a **one-shot** query — spawns a single process for a quick task without maintaining a session or requiring a tmux pane:

```
:Codeboomer AskOneOff
```

**When to use one-off mode:**
- Quick questions or single commands that don't require conversational context
- Testing or experimentation without session overhead
- Running isolated tasks where you want a clean slate each time
- Situations where you don't have or need a tmux pane running

**How it works:**
Opens the same input UI as `SendPrompt`, then spawns a fresh process for your query and shows the answer in a notification when it finishes. Works with or without a visual selection: with one, the selection is included as context (file and line numbers); without one, the current file name is sent as context instead.

- The input submits on `<CR>` and closes itself — `<C-j>` (insert mode) or `o` (normal mode) if you need a newline
- The prompt is passed as an argv vector via `vim.system`, so quotes, `$`, backticks and newlines in your message are never interpreted by a shell
- Runs asynchronously with a 60s timeout — the editor never freezes while the LLM thinks
- Failures surface the exit code and stderr in an `ERROR` notification

### `:Codeboomer Annotate`

Adds the current selection to an accumulated query context. Use this to annotate multiple code sections before sending a directive.

- Requires a pane to be selected first via `:Codeboomer SetPane`
- The selection is stored and will be included in the next `:Codeboomer FlushWithDirective` call

```
:'<,'>Codeboomer Annotate
```

### `:Codeboomer FlushWithDirective`

> [!warn] **Tentative API** — This command is experimental and subject to change in future versions.

Opens fzf to select a pre-defined directive, then sends it along with all previously accumulated annotations from `:Codeboomer Annotate`.

- Requires a pane to be selected first via `:Codeboomer SetPane`
- Select from a list of pre-defined directives (see Configuration below for customizing)
- After sending, the annotation context is cleared

```vim
:Codeboomer FlushWithDirective
```

## How it works

### Basic workflow

1. Select a pane with `<leader>cp` or `:Codeboomer SetPane`
2. Send a prompt with `<leader>cs` (`:Codeboomer SendPrompt`), or send the selection as-is with `<leader>cr` (`:Codeboomer SendSelection`)
3. For prompts sent with a selection, the plugin includes file path and line numbers in the message

### Annotation workflow

For more complex queries, you can build up context across multiple selections:

1. Select a pane with `<leader>cp`
2. Select code sections and run `<leader>ca` (or `:Codeboomer Annotate`) to add annotations to your query
3. When ready, run `<leader>cd` (or `:Codeboomer FlushWithDirective`) to send your directive along with all accumulated annotations

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
vim.opt.runtimepath:append("/path/to/codeboomer.nvim")
require("codeboomer").setup()
```

**Update the path** in `dev.lua` to point at your local clone, then launch:

```bash
nvim -u dev.lua


```
This gives you an isolated Neovim instance with the plugin loaded, nfnl active, and auto-compilation working — write any `.fnl` file and the corresponding `.lua` updates immediately.

For testing the repo's copy against your **regular** Neovim config (it is prepended to the runtimepath, so it shadows any installed version — rebuild artifacts with `nfnl` first), use `./test-codeboomer`. It requires `CODEBOOMER_PATH` to point at the plugin directory and wires up the full keymap set (`<leader>cs`, `<leader>cr`, `<leader>cc`, `<leader>cd`, `<leader>cp`, `<leader>ca`):

```bash
CODEBOOMER_PATH=$PWD ./test-codeboomer
```

### Project structure

```
.
├── .nfnl.fnl            # nfnl configuration (compiler options, macros, orphan detection)
├── dev.lua               # dev launcher (nvim -u dev.lua)
├── test-codeboomer             # test script for local development
├── test-input.lua        # test script for input UI
├── .envrc                # direnv configuration
├── .stylua.toml          # Lua styling configuration
├── plugin/
│   └── codeboomer.lua      # registers the :Codeboomer user command
├── ftplugin/
│   └── fennel.lua        # Fennel filetype plugin
├── fnl/
│   ├── .nfnl.fnl         # local nfnl configuration
│   ├── test.fnl          # test utilities
│   └── codeboomer/
│       ├── init.fnl      # main module (commands, tmux interaction)
│       ├── config.fnl    # keymap defaults & setup
│       ├── directives.fnl # directive definitions and handling
│       └── input.fnl     # floating input UI
└── lua/
    ├── test.lua          # compiled test utilities
    ├── nfnl/
    │   └── nfnl/
    │       └── fennel.lua # embedded Fennel runtime
    └── codeboomer/
        ├── init.lua      # ← compiled from fnl/codeboomer/init.fnl
        ├── config.lua    # ← compiled from fnl/codeboomer/config.fnl
        ├── directives.lua # ← compiled from fnl/codeboomer/directives.fnl
        └── input.lua     # ← compiled from fnl/codeboomer/input.fnl
```

### Trusting the repo

You need to trust the repo for the plugin to compile your code. Open a fennel buffer, follow the prompt, press `v` to view and then run `:trust` in the empty buffer that Neovim opens.

## LLM assistance

- GLM 5.2

## License

MIT
