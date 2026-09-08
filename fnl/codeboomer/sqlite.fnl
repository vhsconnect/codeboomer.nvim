(local sqlite (require :sqlite))
(local tbl (require :sqlite.tbl))

(local db (sqlite {:uri :/home/vhs/.local/share/nvim/codeboomer
                   :opts {:journal_mode :WAL
                          :synchronous :NORMAL
                          :busy_timeout 500
                          :foreign_keys :ON
                          :auto_vacuum :INCREMENTAL}}))

;; sqlite has no enum type and the schema dsl has no CHECK constraint,
;; so thread status is validated app-side
(fn assert-valid-status [status]
  (assert (or (= status :open) (= status :resolved))
          (.. "invalid thread status: " (tostring status))))

(local user-schema
       {:id true :name :text :email {:type :text :required true :unique true}})

(local repo-schema {:id true :path {:type :text :unique true}})

(local commit-schema {:id true
                      :hash {:type :text :required true :unique true}
                      :repo {:type :integer
                             :reference :repo.id
                             :on_delete :cascade}})

(local session-schema {:id true
                       :name :text
                       :branch :text
                       :head_commit {:type :integer
                                     :reference :git_commit.id
                                     :on_delete :cascade}
                       :repo_id {:type :integer
                                 :reference :repo.id
                                 :on_delete :cascade}})

(local thread-schema {:id true
                      :session_id {:type :integer
                                   :reference :session.id
                                   :on_delete :cascade}
                      :file_path {:type :text :required true}
                      :line_start :integer
                      :line_end :integer
                      :code_snapshot :text
                      :anchor_commit {:type :integer
                                      :reference :git_commit.id
                                      :on_delete :cascade}
                      :status {:type :text :required true}
                      :created_by {:type :integer
                                   :reference :user.id
                                   :on_delete :cascade}
                      :created_at {:type :integer
                                   :default (sqlite.lib.strftime "%s" :now)}
                      :deleted_at :integer})

(local comment-schema {:id true
                       :thread_id {:type :integer
                                   :reference :comment_thread.id
                                   :on_delete :cascade}
                       :body {:type :text :required true}
                       :commit_id {:type :integer
                                   :reference :git_commit.id
                                   :on_delete :cascade}
                       :author_id {:type :integer
                                   :reference :user.id
                                   :on_delete :cascade}
                       :created_at {:type :integer
                                    :default (sqlite.lib.strftime "%s" :now)}
                       :deleted_at :integer})

(local user (tbl :user user-schema db))
(local repo (tbl :repo repo-schema db))
(local session (tbl :session session-schema db))
(local commit (tbl :git_commit commit-schema db))
(local thread (tbl :comment_thread thread-schema db))
(local comments (tbl :comment comment-schema db))

;; soft deletes: rows keep deleted_at set; filter in lua because the where
;; dsl can't express "is null" (strings bind as equality unless prefixed < or >)
(fn active-rows [rows]
  (let [out []]
    (each [_ row (ipairs rows)]
      (when (= row.deleted_at nil)
        (table.insert out row)))
    out))

(local M {: db
          : user
          : repo
          : session
          : commit
          : thread
          : comments
          : assert-valid-status
          : active-rows})

M
