# compis.nvim

A minimal Neovim plugin for querying LLM providers from inside the editor. Written in [Fennel](https://fennel-lang.org/), compiled to Lua automatically via [nfnl](https://github.com/Olical/nfnl).

## Installation

```lua
-- lazy.nvim
{
  "your-org/compis.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("compis").setup()
  end,
}
```

## Configuration

Call `setup()` with any of these overrides:

```lua
require("compis").setup({
  provider = "ollama", -- default provider

  openai = {
    endpoint = "https://api.openai.com/v1",
    model = "gpt-4o",
    timeout = 30000,
    temperature = 0,
    max_tokens = 4096,
  },

  copilot = {
    endpoint = "https://api.githubcopilot.com",
    model = "gpt-4o-2024-05-13",
    timeout = 30000,
    temperature = 0,
    max_tokens = 4096,
  },

  claude = {
    endpoint = "https://api.anthropic.com",
    model = "claude-3-5-sonnet-20240620",
    timeout = 30000,
    temperature = 0,
    max_tokens = 8000,
  },

  gemini = {
    endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
    model = "gemini-1.5-flash-latest",
    timeout = 30000,
    temperature = 0,
    max_tokens = 4096,
  },

  openrouter = {
    endpoint = "https://openrouter.ai/api/v1",
    model = "deepseek/deepseek-v3.2",
    timeout = 30000,
    temperature = 0,
    max_tokens = 4096,
  },

  ollama = {
    endpoint = "http://localhost:11434",
    model = "nemotron-mini:latest",
    timeout = 30000,
    temperature = 0,
    max_tokens = 4096,
  },
})
```

### Provider API keys

For cloud providers the plugin reads these environment variables automatically:

| Provider | Env var |
|----------|---------|
| OpenAI | `OPENAI_API_KEY` |
| Claude | `ANTHROPIC_API_KEY` |
| OpenRouter | `OPENROUTER_API_KEY` |
| Ollama | *(none needed — local only)* |

Other providers (Copilot, Azure, Gemini, Cohere) are configured but don't yet have automatic key lookup — set the key manually or contribute it.

## Commands

### `:Compis`

Asks the configured LLM a question and shows the response in a notification.

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
│       ├── init.fnl    # main module (setup, ask)
│       ├── config.fnl  # defaults & provider config
│       └── provider.fnl # HTTP layer (plenary.curl)
└── lua/
    ├── compis/
    │   ├── init.lua    # ← compiled from fnl/compis/init.fnl
    │   ├── config.lua  # ← compiled from fnl/compis/config.fnl
    │   └── provider.lua # ← compiled from fnl/compis/provider.fnl
    └── nfnl/            # embedded nfnl runtime (not hand-edited)


```

### Trusting the repo
- you need to trust the repo for the plugin to compile your code. Open a fennel buffer. Follow the prompt, `v` to view and then `:trust` in the empty buffer that neovim opens.

## License

MIT
