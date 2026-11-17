(global vim vim)

(var db nil)

;; the schema version, part of the database's file name. Any schema
;; change bumps it: there are no migrations, a new version starts an
;; empty file and earlier files stay on disk untouched
(local db-version 2)

(fn db-path []
  (string.format "%s/codeboomer-db-v%d" (vim.fn.stdpath :data) db-version))

;; the one piece of schema sqlite.lua's dsl cannot express: a
;; composite unique index — one session per (repo, branch). Runs once
;; per process on the first
;; connection; the tables are created first because no tbl call has
;; had the chance to on a fresh database (delete-session's raw sql
;; relies on them too, and its foreign key checks on the tables
;; they reference)
(var schema-ready nil)
(fn ensure-schema []
  (when (and (not schema-ready) db)
    (set schema-ready true)
    (let [sqlite (require :codeboomer.sqlite)]
      (each [_ tbl (ipairs [sqlite.user
                            sqlite.repo
                            sqlite.commit
                            sqlite.session
                            sqlite.thread
                            sqlite.comments])]
        (tbl db)))
    (db:with_open (fn [d]
                    (d:execute "create unique index if not exists session_branch
                    on session (repo_id, branch)")))))

;; sqlite.lua's insert is not exception safe: a throwing bind (an
;; unbindable column value) skips both the statement's finalize and
;; the COMMIT of its BEGIN, leaving a live statement and an open write
;; transaction on the connection — and sqlite3_close refuses a
;; connection with live statements. This is the cleanup its missing
;; finally block would have run
(fn release-statements [conn]
  (let [clib (require :sqlite.defs)]
    (var stmt (clib.next_stmt conn nil))
    (while (not= nil stmt)
      (clib.finalize stmt)
      (set stmt (clib.next_stmt conn nil)))
    (when (= 0 (clib.get_autocommit conn))
      (clib.exec_stmt conn :ROLLBACK))))

(fn force-close []
  (when db
    (when (db:isopen)
      (pcall release-statements db.conn)
      (pcall #(db:close)))
    (set db nil)))

(local M {:get-db (fn get-db []
                    ;; sqlite.nvim is required here, not at the top
                    ;; level, so merely loading this module never
                    ;; loads the dependency — the connection (and
                    ;; with it the require) happens on the first
                    ;; actual db call
                    (case db
                      nil (let [sqlite (require :sqlite)]
                            (set db
                                 (sqlite {:uri (db-path)
                                          :opts {:journal_mode :WAL
                                                 :synchronous :NORMAL
                                                 :busy_timeout 500
                                                 :foreign_keys :ON
                                                 :auto_vacuum :INCREMENTAL
                                                 :wal_autocheckpoint 100}}))
                            (ensure-schema)
                            db)
                      _ db))
          ;; with_open (mark-annotations) closes the shared handle
          ;; after each call, so only close what is actually open —
          ;; then drop the reference so a later get-db builds a
          ;; fresh connection
          :close-db (fn close-db [] (force-close))
          ;; the db macro calls this after any failed tbl call so the
          ;; NEXT write gets a fresh connection instead of inheriting
          ;; a wedged one. Same mechanics as close-db — the split
          ;; name only documents intent
          :reset-db (fn reset-db [] (force-close))
          : db-path})

;; checkpoint + close on exit. sqlite.lua connects per operation and
;; closes right after (every tbl call is wrapped in with_open when the
;; handle is idle), so this is a safety net for anything an interrupted
;; flow leaves open — dying with a handle abandons the -wal/-shm pair
;; for the next startup to recover. A no-op when the db was never opened
(vim.api.nvim_create_autocmd :VimLeavePre {:callback (fn [] (M.close-db))})

M
