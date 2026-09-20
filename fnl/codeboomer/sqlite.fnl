(global vim vim)

;; sqlite has no enum type and the schema dsl has no CHECK constraint,
;; so thread status is validated app-side
(fn assert-valid-status [status]
  (assert (or (= status :open) (= status :resolved))
          (.. "invalid thread status: " (tostring status))))

(local created-at-default "strftime('%s', 'now')")

(local user-schema
       {:id true :name :text :email {:type :text :required true :unique true}})

(local repo-schema {:id true :path {:type :text :unique true}})

(local commit-schema {:id true
                      :hash {:type :text :required true :unique true}
                      :repo {:type :integer
                             :reference :repo.id
                             :on_delete :cascade}})

;; a session is the unit of review: "live" ones carry the branch and
;; the HEAD they were created at; PR ones (review mode) additionally
;; pin the PR number and the base commit the head is diffed against
(local session-schema {:id true
                       :branch :text
                       :head_commit {:type :integer
                                     :reference :git_commit.id
                                     :on_delete :cascade}
                       :base_commit {:type :integer
                                     :reference :git_commit.id
                                     :on_delete :cascade}
                       :pr_number :integer
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
                      ;; set on threads seeded from outdated GitHub
                      ;; comments (position null after new commits)
                      :gh_outdated :integer
                      :created_by {:type :integer
                                   :reference :user.id
                                   :on_delete :cascade}
                      :created_at {:type :integer :default created-at-default}
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
                       ;; user, agent, github
                       :source :text
                       ;; set on comments pulled down from a GitHub PR —
                       ;; the stable id that makes re-pulls idempotent.
                       ;; Stored as text, not integer: sqlite.lua's row
                       ;; reader (sqlstmt:val) dispatches every INTEGER
                       ;; column through sqlite3_column_int (32-bit), which
                       ;; silently wraps GitHub's billion-scale comment ids
                       ;; into garbage negative numbers on every read
                       :gh_comment_id {:type :text :unique true}
                       :sent {:type :integer :default 0}
                       :posted {:type :integer :default 0}
                       :created_at {:type :integer :default created-at-default}
                       :deleted_at :integer})

;; the table helpers. NOTE: the callable class lives in the :sqlite.tbl
;; module — (require :sqlite).tbl resolves through the module proxy to
;; the db:tbl method, whose string-self path silently drops the db
;; argument, so every helper would fail its first :get/:insert with
;; "db object is not set". The require stays inside each helper so
;; loading this module never loads sqlite.nvim
(local user (fn [db]
              ((require :sqlite.tbl) :user user-schema db)))

(local repo (fn [db]
              ((require :sqlite.tbl) :repo repo-schema db)))

(local session
       (fn [db]
         ((require :sqlite.tbl) :session session-schema db)))

(local commit
       (fn [db]
         ((require :sqlite.tbl) :git_commit commit-schema db)))

(local thread
       (fn [db]
         ((require :sqlite.tbl) :comment_thread thread-schema db)))

(local comments
       (fn [db]
         ((require :sqlite.tbl) :comment comment-schema db)))

;; soft deletes: rows keep deleted_at set; filter in lua because the where
;; dsl can't express "is null" (strings bind as equality unless prefixed < or >)
(fn active-rows [rows]
  (let [out []]
    (each [_ row (ipairs rows)]
      (when (= row.deleted_at nil)
        (table.insert out row)))
    out))

(local M {: user
          : repo
          : session
          : commit
          : thread
          : comments
          : assert-valid-status
          : active-rows})

M
