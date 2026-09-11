(global vim vim)
(local git (require :codeboomer.git))
(local sqlite (require :codeboomer.sqlite))
(local M {})

(fn with-user []
  (let [email (git.user-email)
        entry? (sqlite.user:get {:where {: email}})]
    (if (. entry? 1) (?. entry? 1 :id)
        (sqlite.user:insert {:name (git.user-name) : email}))))

;; the one synthetic identity all agent-written comments share —
;; get-or-create like with-user, fixed coordinates
(fn with-agent-user []
  (let [entry? (sqlite.user:get {:where {:email "agent@codeboomer"}})]
    (if (. entry? 1) (?. entry? 1 :id)
        (sqlite.user:insert {:name "agent" :email "agent@codeboomer"}))))

(fn with-repo []
  (let [repo-path (git.repo-root)
        entry? (sqlite.repo:get {:where {:path repo-path}})]
    (if (. entry? 1) (?. entry? 1 :id) (sqlite.repo:insert {:path repo-path}))))

(fn with-commit [repo-id]
  (let [commit-hash (git.head-sha)
        entry? (sqlite.commit:get {:where {:hash commit-hash}})]
    (if (. entry? 1) (?. entry? 1 :id)
        (sqlite.commit:insert {:hash commit-hash :repo repo-id}))))

(fn M.user-comment [session-id file-path line-start line-end code body]
  (let [user-id (with-user)
        repo-id (with-repo)
        commit-id (with-commit repo-id)
        thread-id (sqlite.thread:insert {:session_id session-id
                                         :file_path file-path
                                         :line_start line-start
                                         :line_end line-end
                                         :code_snapshot code
                                         :anchor_commit commit-id
                                         :status :open
                                         :created_by user-id})]
    (sqlite.comments:insert {:thread_id thread-id
                             :author_id user-id
                             : body
                             :source "user"
                             :commit_id commit-id})))

(fn M.get-sessions []
  (sqlite.session:get {:where {:repo_id (with-repo)}}))

(fn M.agent-reply [thread-id body]
  ;; the agent's answer to an existing thread: no new session/repo/
  ;; commit lookups — everything anchors to the thread it answers.
  ;; source "agent" keeps the row out of both delivery outboxes.
  ;; Returns the comment id, or nil (+ message) when the target is
  ;; missing, soft-deleted, or the body is empty.
  (let [rows (or (sqlite.thread:get {:where {:id thread-id}}) [])
        thread (. rows 1)]
    (if (or (not thread) thread.deleted_at)
        (do (vim.notify (.. "codeboomer: no active thread #" (tostring thread-id))
                        vim.log.levels.ERROR)
            nil)
        (= "" (or body ""))
        (do (vim.notify "codeboomer: empty reply body"
                        vim.log.levels.ERROR)
            nil)
        (sqlite.comments:insert {:thread_id thread-id
                                 :author_id (with-agent-user)
                                 : body
                                 :source "agent"
                                 :commit_id thread.anchor_commit}))))

;; the one review session a pane should mirror: nil when none exists yet,
;; its id when there is exactly one — the multi-session case keeps the
;; same "not implemented" policy as init's with-session macro.
;; Read-only: an unknown repo yields nil instead of registering the
;; repo, so the sidebar's startup load never writes to the DB
(fn M.active-session-id []
  (let [root (git.repo-root)]
    (when root
      (let [repo-id (?. (sqlite.repo:get {:where {:path root}}) 1 :id)]
        (when repo-id
          (let [sessions (or (sqlite.session:get {:where {:repo_id repo-id}})
                             [])]
            (case (length sessions)
              0 nil
              1 (?. sessions 1 :id)
              _ (error "Multiple session not implemented"))))))))

;; sha of a git_commit row — the GitHub reviews API anchors reviews
;; with the commit SHA, not our local row id
(fn M.commit-sha [commit-id]
  (?. (sqlite.commit:get {:where {:id commit-id}}) 1 :hash))

;; the delivery outbox: my nvim-authored annotations whose flag
;; (:sent or :posted) is still 0, oldest first, each paired with its
;; thread for context. Agent/github-sourced rows and other authors
;; never enter an outbox — they arrived from where they'd be going.
;; Empty bodies are skipped: they were never part of a flush.
(fn M.pending-annotations [session-id flag]
  (if (not session-id)
      []
      (let [me (with-user)
            out []]
        (each [_ t (ipairs (M.threads-for-session session-id))]
          (each [_ c (ipairs (M.comments-for (or t.id 0)))]
            (when (and (= (or c.author_id 0) me)
                       (= (or c.source "user") "user")
                       (= 0 (or (. c flag) 0))
                       (not= "" (or c.body "")))
              (table.insert out {:thread t :comment c}))))
        out)))

;; flip a delivery flag to 1 — raw SQL through with_open (the table
;; helpers have no update-by-id-list, and raw statements need an open
;; connection); the flag is whitelisted, ids come from our own queries
(fn M.mark-annotations [flag ids]
  (when (vim.tbl_contains [:sent :posted] flag)
    (sqlite.db:with_open
      (fn [d]
        (each [_ id (ipairs ids)]
          (d:execute (string.format "update comment set %s = 1 where id = %d"
                                    (tostring flag) (or id 0))))))))

;; active (not soft-deleted) threads of a session anchored to one file,
;; ordered top-to-bottom by their position in the file
(fn M.threads-for [session-id file-path]
  (let [rows (sqlite.active-rows (or (sqlite.thread:get {:where {:session_id session-id
                                                                 :file_path file-path}})
                                     []))]
    (table.sort rows (fn [a b] (< (or a.line_start 0) (or b.line_start 0))))
    rows))

;; active threads of a session across ALL its files, ordered by file
;; path then top-to-bottom within a file — the sidebar turns this into
;; its path → threads map in one load
(fn M.threads-for-session [session-id]
  (let [rows (sqlite.active-rows (or (sqlite.thread:get {:where {:session_id session-id}})
                                     []))]
    (table.sort rows (fn [a b]
                       (let [pa (or a.file_path "")
                             pb (or b.file_path "")]
                         (if (= pa pb)
                             (< (or a.line_start 0) (or b.line_start 0))
                             (< pa pb)))))
    rows))

;; active (not soft-deleted) comments of one thread, oldest first —
;; created_at has second resolution, id breaks ties
(fn M.comments-for [thread-id]
  (let [rows (sqlite.active-rows (or (sqlite.comments:get {:where {:thread_id thread-id}})
                                     []))]
    (table.sort rows (fn [a b]
                       (let [ta (or a.created_at 0) tb (or b.created_at 0)]
                         (if (= ta tb)
                             (< (or a.id 0) (or b.id 0))
                             (< ta tb)))))
    rows))

(fn M.create-session []
  (let [repo-id (with-repo)]
    (sqlite.session:insert {:name :session1
                            :branch (git.branch-name)
                            :head_commit (with-commit repo-id)
                            :repo_id repo-id})))

M
