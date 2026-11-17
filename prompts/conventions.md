- Never migrate the database: any schema change in `sqlite.fnl` bumps `db-version` in `singleton.fnl`, which opens a fresh `codeboomer-db-v<N>` file.
- Leave earlier files untouched, and define tables only through the schemas, since sqlite.lua rebuilds tables whose stored SQL differs.
- Always update the version number -  every tiny change should always bump the patch version - only change the major or minor when I explicitly tell you

