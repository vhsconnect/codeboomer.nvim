;; [nfnl] codeboomer/review.fnl
;; The storage half of codeboomer's threads. A thread row is ONE HALF
;; of a logical thread, labeled by kind:
;;   :local  — the conversation half: annotate notes, agent answers,
;;             a-replies. Never leaves the machine.
;;   :review — the shipping half: the promoted text, r-replies,
;;             pulled gh comments. The only kind PostReview walks.
;; The halves of a pair share path/range/anchor and link through
;; parent_id. Either half can be born alone — fresh annotations
;; start local (the review half appears at promotion), pulled gh
;; comments start review (the local twin appears at the first agent
;; interaction) — and the pane and the flush render the pair as ONE
;; interleaved conversation.
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

;; every annotation starts LOCAL: the note is a conversation with the
;; agent until promotion deliberately creates the shipping half
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
                       :kind :local
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

;; ── gh import (pull down) ───────────────────────────────────── the storage
;; half of PR sync: pulled rows are keyed by GitHub's comment id, so
;; re-pulls never duplicate, and remote authors get real user rows.
;; Pulled threads are born :review — they already exist up there

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
                       :kind :review
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

;; ── thread pairs ──────────────────────────────────────────────
;; sort orders shared by the listings: threads file-first then
;; top-to-bottom, comments by creation time (id breaks same-second
;; ties so rows keep insert order)
(fn by-file-then-line [a b]
  (let [pa (or a.file_path "")
        pb (or b.file_path "")]
    (if (= pa pb)
        (< (or a.line_start 0) (or b.line_start 0))
        (< pa pb))))

(fn by-created [a b]
  (let [ta (or a.created_at 0)
        tb (or b.created_at 0)]
    (if (= ta tb) (< (or a.id 0) (or b.id 0)) (< ta tb))))

(fn thread-by-id [id]
  (?. (db sqlite.thread :get {:where {:id (or id 0)}}) 1))

(fn root-of [t]
  (or (when t.parent_id (thread-by-id t.parent_id)) t))

(fn twin-of [t]
  (let [root (root-of t)]
    (if (= (or root.id 0) (or t.id 0))
        (?. (sqlite.active-rows (db sqlite.thread :get
                                    {:where {:parent_id (or t.id 0)}}))
            1)
        root)))

(fn M.twin [id]
  (let [t (thread-by-id id)]
    (when t (twin-of t))))

;; the pair's whole conversation in one list — both halves' comments
;; interleaved by creation time. The pane renders this and the flush
;; ships it; only the posting outbox reads a single half
(fn M.conversation-comments [thread-id]
  (let [t (thread-by-id thread-id)]
    (if (not t)
        []
        (let [root (root-of t)
              twin (twin-of t)
              rows (vim.list_extend (M.comments-for (or root.id 0))
                                    (if (and twin
                                             (not= (or twin.id 0)
                                                   (or root.id 0)))
                                        (M.comments-for twin.id)
                                        []))]
          (table.sort rows by-created)
          rows))))

;; the local half of a review thread, born on demand at the first
;; agent interaction (an a-reply or an agent answer): a structural
;; clone of the review row, parent-linked back to it. Always returns
;; the ROW (callers read target.id off it)
(fn M.ensure-local-twin [thread-id]
  (let [t (thread-by-id thread-id)]
    (if (not t)
        nil
        (let [twin (twin-of t)]
          (if twin
              twin
              (let [id (db sqlite.thread :insert
                           {:session_id t.session_id
                            :file_path t.file_path
                            :line_start t.line_start
                            :line_end t.line_end
                            :code_snapshot t.code_snapshot
                            :anchor_commit t.anchor_commit
                            :status :open
                            :kind :local
                            :parent_id t.id
                            :created_by (with-user)})]
                (thread-by-id id)))))))

;; promote a local thread: create its :review half carrying the final
;; shipping text — the one deliberate door into the posting outbox.
;; ?session-id is the open PR review's session (defaults to the
;; thread's own), ?anchor-sha the review head the half anchors at
;; (defaults to the thread's own anchor). Returns the twin's id
(fn M.promote [thread-id body ?session-id ?anchor-sha]
  (let [t (thread-by-id thread-id)
        refuse (fn [msg level]
                 (vim.notify msg level)
                 nil)]
    (if (not t)
        (refuse (.. "codeboomer: no thread #" (tostring (or thread-id 0)))
                vim.log.levels.ERROR)
        (= :review (or t.kind :local))
        (refuse "codeboomer: this thread is already a review thread"
                vim.log.levels.WARN)
        (twin-of t)
        (refuse (string.format "codeboomer: thread #%d already promoted"
                               (or t.id 0)) vim.log.levels.WARN)
        (= "" (vim.trim (or body "")))
        (refuse "codeboomer: empty promotion ignored" vim.log.levels.WARN)
        (let [commit-id (with-commit (with-repo)
                          (or ?anchor-sha (M.commit-sha t.anchor_commit)))
              twin-id (db sqlite.thread :insert
                          {:session_id (or ?session-id t.session_id)
                           :file_path t.file_path
                           :line_start t.line_start
                           :line_end t.line_end
                           :code_snapshot t.code_snapshot
                           :anchor_commit commit-id
                           :status :open
                           :kind :review
                           :parent_id t.id
                           :created_by (with-user)})]
          (db sqlite.comments :insert
              {:thread_id twin-id
               :author_id (with-user)
               : body
               :source :user
               :commit_id commit-id})
          twin-id))))

;; rewrite one comment's body in place — the pane's e key refines a
;; promoted (still unposted) comment without touching anything else
(fn M.update-comment-body [comment-id body]
  (db sqlite.comments :update {:set {: body} :where {:id (or comment-id 0)}}))

;; record the gh comment id a local row became — makes re-pulls
;; idempotent for our own posted comments and gives a promoted pair
;; its gh root, so later r-replies route through the replies endpoint
(fn M.stamp-gh-comment [comment-id gh-id]
  (db sqlite.comments :update
      {:set {:gh_comment_id (tostring gh-id)} :where {:id (or comment-id 0)}}))

;; the agent's answer joins the CONVERSATION half: a :review target
;; (a pulled thread the agent was asked about) diverts to its local
;; twin, created on demand — the shim's thread ids stay pair-free
;; without the agent ever knowing halves exist
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
        (let [target (if (= :review (or thread.kind :local))
                         (M.ensure-local-twin thread-id)
                         thread)]
          (when target
            (db sqlite.comments :insert
                {:thread_id target.id
                 :author_id (with-agent-user)
                 : body
                 :source :agent
                 :commit_id target.anchor_commit}))))))

;; a human reply typed in the review pane — routing is the caller's
;; choice: the pane's r key passes the review half (shipping), a the
;; local half (conversation). Unsent/unposted until the matching
;; flush/post walk picks it up
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

;; resolving closes the WHOLE pair: both halves leave every listing
;; and both outboxes at once
(fn M.resolve-thread [thread-id]
  (let [t (thread-by-id thread-id)]
    (db sqlite.thread :update {:set {:status :resolved} :where {:id thread-id}})
    (let [twin (when t (twin-of t))]
      (when twin
        (db sqlite.thread :update
            {:set {:status :resolved} :where {:id twin.id}})))))

;; sha of a git_commit row — the GitHub reviews API anchors reviews
;; with the commit SHA, not our local row id
(fn M.commit-sha [commit-id]
  (?. (db sqlite.commit :get {:where {:id commit-id}}) 1 :hash))

;; ── the two outboxes ──────────────────────────────────────────
;; one predicate, two walks: the flush outbox reads the session's
;; LOGICAL threads (both halves' comments — the agent sees the whole
;; conversation), the posting outbox reads the :review halves only,
;; so local chatter is structurally unreachable from PostReview
(fn mine-unflagged? [c me flag]
  (and (= (or c.author_id 0) me) (= (or c.source :user) :user)
       (= 0 (or (. c flag) 0)) (not= "" (or c.body ""))))

;; my still-unposted comments of one review thread, oldest first —
;; the pane's e key edits the first (the promoted text itself, by
;; construction)
(fn M.unposted-user-comments [thread-id]
  (let [me (with-user)]
    (icollect [_ c (ipairs (M.comments-for (or thread-id 0)))]
      (when (mine-unflagged? c me :posted) c))))

;; unsent user messages of the session's logical threads, either half
;; — the flush outbox; one entry per comment, grouped per thread by
;; the caller
(fn M.pending-for-flush [session-id]
  (if (not session-id)
      []
      (let [me (with-user)
            out []]
        (each [_ t (ipairs (M.threads-for-session session-id))]
          (each [_ c (ipairs (M.conversation-comments (or t.id 0)))]
            (when (mine-unflagged? c me :sent)
              (table.insert out {:thread t :comment c}))))
        out)))

;; unposted user messages of the session's :review halves — the
;; posting outbox
(fn M.pending-for-post [session-id]
  (if (not session-id)
      []
      (let [me (with-user)
            out []]
        (each [_ t (ipairs (M.review-rows-for-session session-id))]
          (each [_ c (ipairs (M.comments-for (or t.id 0)))]
            (when (mine-unflagged? c me :posted)
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

;; the session's LOGICAL threads — one row per pair, the root (the
;; half born first): plain rows pass through, and a promoted twin
;; pulls its root in even when that root lives in another session (a
;; live session's local thread promoted into the PR review still
;; shows there). The pane, the marks and the flush all walk this
(fn M.threads-for-session [session-id]
  (if (not session-id)
      []
      (let [rows (unresolved-rows (sqlite.active-rows (or (db sqlite.thread
                                                              :get
                                                              {:where {:session_id session-id}})
                                                          [])))
            seen {}
            roots []]
        (each [_ row (ipairs rows)]
          (let [root (root-of row)]
            (when (and root (not (. seen (or root.id 0))))
              (tset seen (or root.id 0) true)
              (table.insert roots root))))
        (table.sort roots by-file-then-line)
        roots)))

;; the session's :review halves — what the posting outbox walks.
;; Promoted twins live in the session they were promoted into,
;; pulled threads in the session they were imported to
(fn M.review-rows-for-session [session-id]
  (if (not session-id)
      []
      (let [rows (unresolved-rows (sqlite.active-rows (or (db sqlite.thread
                                                              :get
                                                              {:where {:session_id session-id
                                                                       :kind :review}})
                                                          [])))]
        (table.sort rows by-file-then-line)
        rows)))

(fn M.comments-for [thread-id]
  (let [rows (sqlite.active-rows (or (db sqlite.comments :get
                                         {:where {:thread_id thread-id}})
                                     []))]
    (table.sort rows by-created)
    rows))

;; the author row of a comment — flush messages label each conversation
;; entry with a real name (the local user, the agent, github logins)
(fn M.comment-author [c]
  (?. (db sqlite.user :get {:where {:id (or c.author_id 0)}}) 1))

;; a pulled item that is one of MY posted comments come home: stamp
;; its gh id onto the matching local row instead of duplicating
(fn M.match-posted-comment [session-id item]
  (let [line (or item.line item.original_line)
        want-path (or item.path "")
        want-body (or item.body "")]
    (var found nil)
    (each [_ r (ipairs (M.review-rows-for-session session-id)) &until found]
      (when (= want-path (or r.file_path ""))
        (each [_ c (ipairs (M.comments-for (or r.id 0))) &until found]
          (when (and line (= 1 (or c.posted 0)) (= nil c.gh_comment_id)
                     (= want-body (or c.body "")) (>= line (or r.line_start 0))
                     (<= line (or r.line_end 0)))
            (set found c)))))
    found))

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
