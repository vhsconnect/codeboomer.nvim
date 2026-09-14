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
                      _ db))})

M
