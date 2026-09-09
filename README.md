# codeboomer.nvim

A Neovim plugin for sending text and commands to tmux panes. Useful for sending text blocks to a repl or an AI agent along with some comments or instructions. 

## Features

- Send text from Neovim to any tmux pane
- Fuzzy-finder interface (via fzf-lua) to select target panes, showing each pane's last output line and working directory, with a live content preview
- Visual mode support — send the selection as-is (`SendSelection`) or as context in a composed prompt (`SendPrompt`)
- Annotation workflow — accumulate multiple code selections for review before sending
- **Review comments pane (`Comments`)** — toggle a side split that shows the comment thread under the cursor; it blanks as soon as the cursor leaves the thread's lines, and commented ranges get per-thread colored `✎` gutter marks
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
| Visual | `<leader>ca` | `Annotate` — add the selection (plus an optional note) to the query context |
| Normal | `<leader>cm` | `Comments` — toggle the review comments side pane |
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
    comments = "<leader>cm",
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

Adds the current selection to an accumulated query context. Use this to annotate multiple code sections before sending a directive.

- Requires a pane to be selected first via `:Codeboomer SetPane`
- With a visual range, the selection is included as context (`regarding <file> lines X to Y`); without one, the current file name is sent instead
- The selection is stored and will be included in the next `:Codeboomer FlushWithDirective` call
- The selection (plus note) is also recorded as a comment thread in the review session's database — `:Codeboomer Comments` displays these later

```
:'<,'>Codeboomer Annotate
```

### `:Codeboomer Comments`

Toggles a review-comments side pane — a plain vertical split on the right
that follows the window it was opened from. While the cursor sits inside a
comment thread's line range the pane shows that thread's comments; as soon
as the cursor leaves every thread's lines the pane goes blank.

- Threads come from the current review session (the same one
  `:Codeboomer Annotate` writes to); with no session yet the pane opens empty
- Overlapping threads are shown together, one block per thread (header line
  plus every comment body)
- New annotations show up immediately while the pane is open
- Commented ranges are marked in the followed buffer's gutter (a `✎`
  sign per commented line) for as long as the pane is open; each thread
  gets its own theme-derived color (cycled from `Title`, `Special`,
  `String`, `Function`), overlapping ranges show two consecutive marks
  (the sign column is forced to `auto:2` meanwhile and restored on close)
- When the cursor touches several overlapping threads the pane stacks
  one block per thread, separated by a `─` rule; block headers are tinted
  with the thread's gutter color
- Closing the followed window closes the pane; toggling re-anchors it to the
  current window

```vim
:Codeboomer Comments
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

### Annotation workflow

For more complex queries, you can build up context across multiple selections:

1. Select a pane with `<leader>cp`
2. Select code sections and run `<leader>ca` (or `:Codeboomer Annotate`) to add annotations to your query
3. When ready, run `<leader>cd` (or `:Codeboomer FlushWithDirective`) to send your directive along with all accumulated annotations

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

For testing the repo's copy against your **regular** Neovim config (it is prepended to the runtimepath, so it shadows any installed version — rebuild artifacts with `nfnl` first), use `./test-codeboomer`. It requires `CODEBOOMER_PATH` to point at the plugin directory and wires up the full keymap set (`<leader>cs`, `<leader>cr`, `<leader>cc`, `<leader>cd`, `<leader>cp`, `<leader>ca`, `<leader>cm`):

```bash
CODEBOOMER_PATH=$PWD ./test-codeboomer
```

### Trusting the repo

You need to trust the repo for the plugin to compile your code. Open a fennel buffer, follow the prompt, press `v` to view and then run `:trust` in the empty buffer that Neovim opens.

## LLM assistance

- GLM 5.2

## License

MIT
