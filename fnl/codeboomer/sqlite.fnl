(global vim vim)

(fn assert-valid-status [status]
  (assert (or (= status :open) (= status :resolved))
          (.. "invalid thread status: " (tostring status))))

(local created-at-default "strftime('%s', 'now')")

(local id-column [:integer :primary :key :autoincrement])

(local user-schema
       {:id id-column
        :name :text
        :email {:type :text :required true :unique true}})

(local repo-schema {:id id-column :path {:type :text :unique true}})

(local commit-schema {:id id-column
                      :hash {:type :text :required true :unique true}
                      :repo {:type :integer
                             :reference :repo.id
                             :on_delete :cascade}})

;; a session is the unit of review: one per (repo, branch); Review
;; binds it to the branch's PR once, through pr_number
(local session-schema {:id id-column
                       :branch :text
                       :pr_number :integer
                       :repo_id {:type :integer
                                 :reference :repo.id
                                 :on_delete :cascade}})

(local thread-schema
       {:id id-column
        :session_id {:type :integer :reference :session.id :on_delete :cascade}
        :file_path {:type :text :required true}
        :line_start :integer
        :line_end :integer
        :code_snapshot :text
        :anchor_commit {:type :integer
                        :reference :git_commit.id
                        :on_delete :cascade}
        :status {:type :text :required true}
        :kind :text
        :type {:type :text :default "'line'"}
        :parent_id {:type :integer
                    :reference :comment_thread.id
                    :on_delete :null}
        :gh_outdated :integer
        ;; GitHub's line on the PR head at import; nil when it was
        ;; already outdated then
        :gh_line :integer
        ;; GitHub's line at gh_original_commit — the pair never
        ;; changes, so it stays a valid reference through rebases
        :gh_original_line :integer
        :gh_original_commit {:type :integer
                             :reference :git_commit.id
                             :on_delete :null}
        :created_by {:type :integer :reference :user.id :on_delete :cascade}
        :created_at {:type :integer :default created-at-default}})

(local comment-schema
       {:id id-column
        :thread_id {:type :integer
                    :reference :comment_thread.id
                    :on_delete :cascade}
        :body {:type :text :required true}
        :commit_id {:type :integer
                    :reference :git_commit.id
                    :on_delete :cascade}
        :author_id {:type :integer :reference :user.id :on_delete :cascade}
        :source :text
        ;; text, not integer: sqlite.lua reads INTEGER columns as
        ;; 32-bit, wrapping GitHub's comment ids
        :gh_comment_id {:type :text :unique true}
        :sent {:type :integer :default 0}
        :posted {:type :integer :default 0}
        :created_at {:type :integer :default created-at-default}})

;; the table helpers. NOTE: (require :sqlite).tbl resolves through the
;; module proxy to db:tbl, which silently drops the db argument — the
;; callable class lives in :sqlite.tbl, and that require stays inside
;; the helper so loading this module never loads sqlite.nvim.
;; Wrapper construction re-probes the schema on its own connection —
;; per-call wrappers once froze the editor on a ~200-query reload — so
;; one wrapper is cached per (handle, table).
(var tbl-cache {})

(fn tbl-for [name schema db]
  (let [per-db (or (. tbl-cache db)
                   (let [fresh {}] (tset tbl-cache db fresh) fresh))]
    (or (. per-db name) (let [wrapper ((require :sqlite.tbl) name schema db)]
                          (tset per-db name wrapper)
                          wrapper))))

(local user (fn [db] (tbl-for :user user-schema db)))

(local repo (fn [db] (tbl-for :repo repo-schema db)))

(local session (fn [db] (tbl-for :session session-schema db)))

(local commit (fn [db] (tbl-for :git_commit commit-schema db)))

(local thread (fn [db] (tbl-for :comment_thread thread-schema db)))

(local comments (fn [db] (tbl-for :comment comment-schema db)))

(local M {: user
          : repo
          : session
          : commit
          : thread
          : comments
          : assert-valid-status})

M
