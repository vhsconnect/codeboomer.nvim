# Keep README.md current

You are maintaining `README.md` for codeboomer.nvim. The README is
documentation-only; the source of truth is always the code. Your job is to
bring the README back in sync with the code — not to rewrite it.

## Ground rules

1. **Read before writing.** Load every file listed under "Sources of truth"
   below before touching the README. Never document from memory or from the
   README's own claims.
2. **`fnl/` is the source; `lua/` is generated.** Verify behavior in
   `fnl/codeboomer/*.fnl`. Never document something only visible in
   `lua/*.lua` — if it isn't in `fnl/`, it doesn't exist.
3. **Update in place.** Preserve the existing heading hierarchy, tone,
   table formats, and markdown style. Only change what is factually wrong
   or missing.
4. **Delete stale content.** If the README documents a command, option,
   file, or workflow that no longer exists in the code, remove that entry
   entirely (including its `###` heading). Do not leave "(deprecated)" or
   "(reserved)" placeholders.
5. **Verify every code snippet** against actual names: option keys,
   function signatures, subcommand spellings, argument order. A snippet
   that references a nonexistent key is a bug in the README.
6. **Do not invent features.** Only document what the code does today.
   Nothing speculative.

## Sources of truth (read all of these first)

| File | What it defines |
|------|-----------------|
| `fnl/codeboomer/init.fnl` | public API (`M.*` functions), the `:Codeboomer` workflows, tmux interaction, message composition, annotation format, one-off query runtime behavior |
| `fnl/codeboomer/config.fnl` | `setup()` semantics, the `keymaps` table (action → mode/rhs/desc), built-in defaults (e.g. `default-one-off-command`), how opts are merged/folded |
| `fnl/codeboomer/directives.fnl` | built-in directive constants (`pushback-reasons`, `default-directives`), runtime lookup behavior |
| `fnl/codeboomer/input.fnl` | the floating input UI and its options (e.g. `submit-on-enter`) |
| `plugin/codeboomer.lua` | the exact `:Codeboomer` subcommand set, completion, range/nargs handling |
| `test-codeboomer`, `dev.lua` | real-world `setup()` call shapes; dev launchers |
| `.nfnl.fnl`, `ftplugin/fennel.lua` | build/compile configuration referenced by the Development section |
| `ls`/`find` output of the repo root | the authoritative Project structure tree |

## Section-by-section checklist

Work top to bottom. For each section, verify against the named source and
fix drift:

- **Features** — every bullet must correspond to a real capability in
  `init.fnl`/`plugin/codeboomer.lua` (pane selection, visual-mode send,
  annotation accumulation, bracketed paste, one-off queries, directive
  picker, …). Add bullets for shipped-but-undocumented capabilities;
  remove bullets for removed ones.
- **Installation** — the lazy.nvim snippet must use the current `setup()`
  option shape.
- **Configuration → Keybindings** — the Mode/Binding/Description table
  must match the `keymaps` table in `config.fnl` (all six actions:
  `send_prompt`, `send_selection`, `ask_one_off`, `pane`, `annotate`,
  `flush_with_directive`) and the real rhs of each mapping. The example
  snippet must nest options under `keybindings = { ... }` with exactly
  these key names. Document `false`-to-disable.
- **Configuration → Prompting** —
  - `prompting.directives`: entry shape (`label`, `text`), built-in
    labels and their exact texts (copy verbatim from
    `directives.fnl`), override-by-label and append-new-labels
    semantics as implemented in `config.fnl`'s fold.
  - `prompting.one_off_command`: static argv list semantics — stored
    without the prompt, composed prompt appended as the **final
    argument** at runtime (see `run-one-off` in `init.fnl`). Default
    value is `default-one-off-command` in `config.fnl`; the README
    example may show a different override but must state the actual
    default. Also document the output-handling contract (JSON with a
    `result` field is unwrapped; other output shown raw) and note the
    60 s timeout if still hardcoded.
- **Commands** — the set of `### :Codeboomer <Name>` sections must equal
  the `subcommands` table in `plugin/codeboomer.lua`, no more, no less.
  For each, check argument/range behavior against how `init.fnl`
  consumes `opts` (`fargs`, `line1`/`line2`, `range`, visual-mode
  context capture). Keep the workflow descriptions (annotation
  `==Section Start==` / `====` / `==Section End==` format) verbatim with
  `concat-list-with-format`.
- **How it works** — the two workflows (basic, annotation) must match
  `M.SendPrompt` / `M.SendSelection` / `M.Annotate` /
  `M.FlushWithDirective` control flow,
  including the pick-a-pane-first behavior of the `with-pan` macro
  (continuation runs only after a pane is chosen; aborting cancels).
- **Development** — build explanation (nfnl compile-on-save, orphan
  detection), the `:Nfnl*` command list, `dev.lua` usage, and
  `CODEBOOMER_PATH=$PWD ./test-codeboomer` instructions must match the current
  scripts. `test-codeboomer`'s inline `setup()` example must reflect its
  actual contents.
- **Launcher sync (`dev.lua` and `test-codeboomer`)** — these two files are
  executable documentation: when the README's configuration examples or
  the plugin's option surface changes, update them in the same pass so
  all three stay in lockstep. Verify that (a) `dev.lua`'s `opts` table
  and `test-codeboomer`'s inline `setup(...)` use the current option shape
  (nested `keybindings`/`prompting`, correct key spellings), (b) every
  `setup()` call site in both files matches a documented, still-valid
  option, and (c) the README's Development section descriptions of
  these launchers match what the files actually do. If either file
  sets an override (e.g. `one_off_command` in `test-codeboomer`), the README
  example may differ, but both must be individually correct. Confirm
  `sh -n test-codeboomer` still passes after edits.
- **Project structure** — regenerate the tree from a real `find . -not
  -path '*/.git/*'` run. One line per file with a short comment; the
  `lua/` files must be marked as compiled from their `fnl/`
  counterparts. Remove entries for deleted files; add entries for new
  ones.
- **Trusting the repo / LLM assistance / License** — verify they still
  apply; update the model list if stale.

## Process

1. Read all sources of truth.
2. Diff your findings against the README, section by section, using the
   checklist above.
3. Apply minimal edits to fix each drift point.
4. Re-read the final README end to end: no orphaned references to
   removed options or commands, no duplicated sections, snippets
   syntactically valid Lua, and every cross-referenced heading present.
5. Report a bullet list of every change made and why, plus anything you
   found ambiguous (rather than guessing).
