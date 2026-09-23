(global vim vim)

(var db nil)

;; a failed bind (an unbindable column value) aborts sqlite.lua's
;; insert loop between parse and finalize, leaving statements
;; unfinalized; sqlite3_close then refuses the close forever, the
;; connection's closed flag is stuck false and every later call
;; reuses the same wedged handle (its with_open paths fail outright).
;; sqlite3_close_v2 is the api built for exactly this: it accepts the
;; close and the engine frees the handle once the last statement
;; finalizes, instead of leaking the connection for the process
;; lifetime
(fn force-close []
  (when db
    (pcall (fn [] (when (db:isopen) (db:close))))
    (when (and db (db:isopen))
      (pcall (fn []
               ((. (require :sqlite.defs) :close_v2) db.conn))))
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
                                 (sqlite {:uri (.. (vim.fn.stdpath :data)
                                                   :/codeboomer)
                                          :opts {:journal_mode :WAL
                                                 :synchronous :NORMAL
                                                 :busy_timeout 500
                                                 :foreign_keys :ON
                                                 :auto_vacuum :INCREMENTAL
                                                 :wal_autocheckpoint 100}}))
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
          :reset-db (fn reset-db [] (force-close))})

;; checkpoint + close on exit. sqlite.lua connects per operation and
;; closes right after (every tbl call is wrapped in with_open when the
;; handle is idle), so this is a safety net for anything an interrupted
;; flow leaves open — dying with a handle abandons the -wal/-shm pair
;; for the next startup to recover. A no-op when the db was never opened
(vim.api.nvim_create_autocmd :VimLeavePre {:callback (fn [] (M.close-db))})

M
