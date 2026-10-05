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

(local M {: user
          : repo
          : session
          : commit
          : thread
          : comments
          : assert-valid-status})

M
