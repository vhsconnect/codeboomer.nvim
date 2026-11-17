- Keep code formatted by running `nix run nixpkgs#fnlfmt` or `fnlfmt` on source code after you make edits but before you compile.
- `bb format` (fnlfmt every Fennel source in place) and `bb build` (format,
  then compile) wrap that loop — prefer them when working from the repo root.
