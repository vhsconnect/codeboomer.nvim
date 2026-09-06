(global vim vim)

(local sqlite (require :sqlite))
(local tbl (require :sqlite.tbl))

(local db (sqlite {:uri :/home/vhs/.local/share/nvim/codeboomer
                   :opts {:journal_mode :WAL
                          :synchronous :NORMAL
                          :busy_timeout 500
                          :foreign_keys :ON
                          :auto_vacuum :INCREMENTAL}}))

(local user-schema {:id true :name :text :email :text})

(local repo-schema {:id true :path :text :name :text})

(local branch-schema {:id true
                      :name :text
                      :head_commit_sha :text
                      :repo_id {:type :integer
                                :reference :repo.id
                                :on_delete :cascade}})

(local comment-thread-schema {:id true
                              :repo_id {:type :integer
                                        :reference :repo.id
                                        :on_delete :cascade}
                              :branch_id {:type :integer
                                          :reference :branch.id
                                          :on_delete :cascade}
                              :file_path :text
                              :line_start :integer
                              :line_end :integer
                              :code_snapshot :text
                              :anchor_commit_sha :text
                              ;make this an enum (open, resolved)
                              :status :text
                              :created_by {:type :integer
                                           :reference :user.id
                                           :on_delete :cascade}
                              :created_at {:type :date
                                           :default (sqlite.lib.strftime "%s"
                                                                         :now)}
                              :deleted_at :date})

(local comment-schema {:id true
                       :thread_id {:type :integer
                                   :reference :comment_thread.id
                                   :on_delete :cascade}
                       :body :text
                       :author_id {:type :integer
                                   :reference :user.id
                                   :on_delete :cascade}
                       :created_at {:type :date
                                    :default (sqlite.lib.strftime "%s" :now)}
                       :created_by {:type :integer
                                    :reference :user.id
                                    :on_delete :cascade}
                       :deleted_at :date})

(local user (tbl :user user-schema db))
(local repo (tbl :repo repo-schema db))
(local branch (tbl :branch branch-schema db))
(local comments-thread (tbl :comment_thread comment-thread-schema db))
(local comments (tbl :comment comment-schema db))

(branch:remove)

(repo:where {:id 1})
(branch:get {:where {:repo 1}})
(comments:count)
(comments:each (fn [row] (print row.content)))
(comments:each (fn [row] (print row.content)))
