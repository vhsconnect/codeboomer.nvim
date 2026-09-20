(global vim vim)
(local git (require :codeboomer.git))
(local sqlite (require :codeboomer.sqlite))
(local s (require :codeboomer.singleton))
(local M {})

(import-macros {: db} :codeboomer.macros)

(fn with-user []
  (let [email (git.user-email)
        entry? (db sqlite.user :get {:where {: email}})]
    (if (. entry? 1) (?. entry? 1 :id)
        (db sqlite.user :insert {:name (git.user-name) : email}))))

;; the one synthetic identity all agent-written comments share —
;; get-or-create like with-user, fixed coordinates
(fn with-agent-user []
  (let [entry? (db sqlite.user :get {:where {:email "agent@codeboomer"}})]
    (if (. entry? 1) (?. entry? 1 :id)
        (db sqlite.user :insert {:name :agent :email "agent@codeboomer"}))))

(fn with-repo []
  (let [repo-path (git.repo-root)
        entry? (db sqlite.repo :get {:where {:path repo-path}})]
    (if (. entry? 1) (?. entry? 1 :id)
        (db sqlite.repo :insert {:path repo-path}))))

(fn with-commit [repo-id ?sha]
  ;; get-or-create a git_commit row — HEAD's when no sha is passed
  (let [commit-hash (or ?sha (git.head-sha))]
    (when commit-hash
      (let [entry? (db sqlite.commit :get {:where {:hash commit-hash}})]
        (if (?. entry? 1 :id) (?. entry? 1 :id)
            (db sqlite.commit :insert {:hash commit-hash :repo repo-id}))))))

(fn M.user-comment [session-id file-path line-start line-end code body]
  (let [user-id (with-user)
        repo-id (with-repo)
        commit-id (with-commit repo-id)
        thread-id (db sqlite.thread :insert
                      {:session_id session-id
                       :file_path file-path
                       :line_start line-start
                       :line_end line-end
                       :code_snapshot code
                       :anchor_commit commit-id
                       :status :open
                       :created_by user-id})]
    (db sqlite.comments :insert
        {:thread_id thread-id
         :author_id user-id
         : body
         :source :user
         :commit_id commit-id})))

;; ── the chosen session ───────────────────────────────────────
;; Explicit module state: writes (annotate, flush) and the review pane
;; all target it. init's picker and ensure-session set it; the zero-
;; and one-session cases resolve silently so the common flow never
;; sees a picker.
(var current-session-id nil)

(fn M.current-session-id [] current-session-id)

(fn M.set-session [id ?silent]
  (set current-session-id id)
  (when (not ?silent)
    (vim.api.nvim_exec_autocmds :User {:pattern :CodeboomerSessionChanged})))

(fn M.existing-sessions []
  (let [root (git.repo-root)]
    (when root
      (let [repo-id (?. (db sqlite.repo :get {:where {:path root}}) 1 :id)]
        (when repo-id
          (let [sessions (or (db sqlite.session :get
                                 {:where {:repo_id repo-id}})
                             [])]
            (table.sort sessions (fn [a b] (< (or a.id 0) (or b.id 0))))
            sessions))))))

(fn M.session-for-pr [pr-number]
  (when pr-number
    (let [root (git.repo-root)]
      (when root
        (let [repo-id (?. (db sqlite.repo :get {:where {:path root}}) 1 :id)]
          (when repo-id
            (?. (db sqlite.session :get
                    {:where {:repo_id repo-id :pr_number pr-number}})
                1)))))))

(fn M.session-by-id [id]
  (when id
    (?. (db sqlite.session :get {:where {: id}}) 1)))

;; ── gh import (pull down) ───────────────────────────── the storage
;; half of PR sync: pulled rows are keyed by GitHub's comment id, so
;; re-pulls never duplicate, and remote authors get real user rows

(fn M.comment-by-gh [gh-id]
  (when gh-id
    (?. (db sqlite.comments :get {:where {:gh_comment_id (tostring gh-id)}}) 1)))

(fn M.thread-id-for-gh [gh-id]
  (when gh-id
    (?. (M.comment-by-gh gh-id) :thread_id)))

;; GitHub payloads carry logins, not emails — synthesize a stable
;; noreply address so remote authors share the user table
(fn M.with-gh-user [login]
  (let [email (.. (or login :unknown) "@users.noreply.github.com")
        entry? (db sqlite.user :get {:where {: email}})]
    (if (?. entry? 1 :id) (?. entry? 1 :id)
        (db sqlite.user :insert {:name (or login :unknown) : email}))))

;; one pulled PR comment that seeds a thread — position null means
;; outdated (the PR moved past its line); anchor best-effort at
;; original_line and flag the thread
(fn M.import-thread [session-id item]
  (let [repo-id (with-repo)
        login (?. item :user :login)
        line (or item.line item.original_line 1)
        commit-id (with-commit repo-id item.commit_id)
        thread-id (db sqlite.thread :insert
                      {:session_id session-id
                       :file_path item.path
                       :line_start line
                       :line_end line
                       :anchor_commit commit-id
                       :status :open
                       :gh_outdated (when (not item.position) 1)
                       :created_by (M.with-gh-user login)})]
    (db sqlite.comments :insert
        {:thread_id thread-id
         :author_id (M.with-gh-user login)
         :body item.body
         :source :github
         :commit_id commit-id
         :gh_comment_id (tostring item.id)})
    thread-id))

;; one pulled PR comment joining an existing thread (in_reply_to)
(fn M.import-comment [thread-id item]
  (db sqlite.comments :insert
      {:thread_id thread-id
       :author_id (M.with-gh-user (?. item :user :login))
       :body item.body
       :source :github
       :commit_id (with-commit (with-repo) item.commit_id)
       :gh_comment_id (tostring item.id)}))

;; the thread's root gh comment id — replies post against it; pulled
;; roots precede their replies (api order = import order = id order)
(fn M.gh-root-comment-id [thread-id]
  (accumulate [root nil _ c (ipairs (M.comments-for thread-id))]
    (or root c.gh_comment_id)))

(fn M.agent-reply [thread-id body]
  (let [rows (or (db sqlite.thread :get {:where {:id thread-id}}) [])
        thread (. rows 1)]
    (if (or (not thread) thread.deleted_at (= thread.status :resolved))
        (do
          (vim.notify (.. "codeboomer: no active thread #" (tostring thread-id))
                      vim.log.levels.ERROR)
          nil)
        (= "" (or body ""))
        (do
          (vim.notify "codeboomer: empty reply body" vim.log.levels.ERROR)
          nil)
        (db sqlite.comments :insert
            {:thread_id thread-id
             :author_id (with-agent-user)
             : body
             :source :agent
             :commit_id thread.anchor_commit}))))

;; a human reply typed in the review pane: like agent-reply but
;; authored by the local user and left unsent — it joins the flush
;; outbox like any annotation, so the next FlushWithDirective ships it
(fn M.user-reply [thread-id body]
  (let [rows (or (db sqlite.thread :get {:where {:id thread-id}}) [])
        thread (. rows 1)]
    (if (or (not thread) thread.deleted_at (= thread.status :resolved))
        (do
          (vim.notify (.. "codeboomer: no active thread #" (tostring thread-id))
                      vim.log.levels.ERROR)
          nil)
        (= "" (or body ""))
        (do
          (vim.notify "codeboomer: empty reply body" vim.log.levels.ERROR)
          nil)
        (db sqlite.comments :insert
            {:thread_id thread-id
             :author_id (with-user)
             : body
             :source :user
             :commit_id thread.anchor_commit}))))

(fn M.resolve-thread [thread-id]
  (db sqlite.thread :update {:set {:status :resolved} :where {:id thread-id}}))

;; sha of a git_commit row — the GitHub reviews API anchors reviews
;; with the commit SHA, not our local row id
(fn M.commit-sha [commit-id]
  (?. (db sqlite.commit :get {:where {:id commit-id}}) 1 :hash))

(fn M.pending-annotations [session-id flag]
  (if (not session-id)
      []
      (let [me (with-user)
            out []]
        (each [_ t (ipairs (M.threads-for-session session-id))]
          (each [_ c (ipairs (M.comments-for (or t.id 0)))]
            (when (and (= (or c.author_id 0) me) (= (or c.source :user) :user)
                       (= 0 (or (. c flag) 0)) (not= "" (or c.body "")))
              (table.insert out {:thread t :comment c}))))
        out)))

(fn M.mark-annotations [flag ids]
  (when (vim.tbl_contains [:sent :posted] flag)
    (: (s.get-db) :with_open
       (fn [d]
         (each [_ id (ipairs ids)]
           (d:execute (string.format "update comment set %s = 1 where id = %d"
                                     (tostring flag) (or id 0))))))))

(fn unresolved-rows [rows]
  (let [out []]
    (each [_ row (ipairs rows)]
      (when (not= row.status :resolved)
        (table.insert out row)))
    out))

(fn M.threads-for-session [session-id]
  (let [rows (unresolved-rows (sqlite.active-rows (or (db sqlite.thread :get
                                                          {:where {:session_id session-id}})
                                                      [])))]
    (table.sort rows (fn [a b]
                       (let [pa (or a.file_path "")
                             pb (or b.file_path "")]
                         (if (= pa pb)
                             (< (or a.line_start 0) (or b.line_start 0))
                             (< pa pb)))))
    rows))

(fn M.comments-for [thread-id]
  (let [rows (sqlite.active-rows (or (db sqlite.comments :get
                                         {:where {:thread_id thread-id}})
                                     []))]
    (table.sort rows (fn [a b]
                       (let [ta (or a.created_at 0)
                             tb (or b.created_at 0)]
                         (if (= ta tb)
                             (< (or a.id 0) (or b.id 0))
                             (< ta tb)))))
    rows))

;; the author row of a comment — flush messages label each conversation
;; entry with a real name (the local user, the agent, github logins)
(fn M.comment-author [c]
  (?. (db sqlite.user :get {:where {:id (or c.author_id 0)}}) 1))

;; create a session row. opts: {:branch :head-sha :base-sha :pr-number} —
;; live sessions pin nothing beyond HEAD-at-creation; PR sessions
;; (review mode) pin both ends of the diff under review
(fn M.create-session [?opts]
  (let [opts (or ?opts {})
        repo-id (with-repo)]
    (db sqlite.session :insert
        {:branch (or opts.branch (git.branch-name))
         :head_commit (with-commit repo-id
                        (?. opts :head-sha))
         :base_commit (with-commit repo-id
                        (?. opts :base-sha))
         :repo_id repo-id
         :pr_number (. opts :pr-number)})))

M
