(global vim vim)

(local sqlite (require :sqlite))

(var db nil)

(local M {:get-db (fn get-db []
                    (case db
                      nil (do
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
          :close-db (fn close-db []
                      ;; with_open (mark-annotations) closes the shared
                      ;; handle after each call, so only close what is
                      ;; actually open — then drop the reference so a
                      ;; later get-db builds a fresh connection
                      (when (and db (: db :isopen))
                        (: db :close))
                      (set db nil))})

;; checkpoint + close on exit. sqlite.lua connects per operation and
;; closes right after (every tbl call is wrapped in with_open when the
;; handle is idle), so this is a safety net for anything an interrupted
;; flow leaves open — dying with a handle abandons the -wal/-shm pair
;; for the next startup to recover. A no-op when the db was never opened
(vim.api.nvim_create_autocmd :VimLeavePre
                             {:callback (fn [] (M.close-db))})

M
