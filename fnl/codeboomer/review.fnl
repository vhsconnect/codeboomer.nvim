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
(local M {})

(import-macros {: db : db-with-open} :codeboomer.macros)

;; sqlite.lua's dsl splices any string matching ^%S+%(...%)$ into the
;; statement as a raw SQL expression instead of binding it — a note
;; shaped like a bare call ("fmt(x)", "count(*)") then fails the
;; write with a cryptic parse error or, when it happens to parse,
;; silently stores the evaluated SQL. A leading space defeats the
;; pattern and is invisible wherever the text renders (markdown
;; trims it); applied to every free-text column at write time
(fn sql-literal [?text]
  (let [v (or ?text "")]
    (if (v:match "^[%S]+%(.*%)$") (.. " " v) v)))

;; ?path picks the repo whose git config names the user — the
;; current buffer's by default; pass the repo of the data at hand
;; when the caller may sit in the comments pane (a nofile buffer
;; resolves through the cwd, which need not be inside the repo)
(fn with-user [?path]
  (let [email (git.user-email ?path)
        entry? (db sqlite.user :get {:where {: email}})]
    (if (. entry? 1) (?. entry? 1 :id)
        (db sqlite.user :insert {:name (git.user-name ?path) : email}))))

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

;; the repo row a session belongs to — the pane-safe source for
;; with-user's ?path and for commit rows
(fn session-repo [session-id]
  (let [session (?. (db sqlite.session :get {:where {:id (or session-id 0)}}) 1)]
    (when session
      (?. (db sqlite.repo :get {:where {:id session.repo_id}}) 1))))

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
                       :code_snapshot (sql-literal code)
                       :anchor_commit commit-id
                       :status :open
                       :type :line
                       :kind :local
                       :created_by user-id})]
    (db sqlite.comments :insert
        {:thread_id thread-id
         :author_id user-id
         :body (sql-literal body)
         :source :user
         :commit_id commit-id})))

;; a whole-file comment — no lines, no snapshot: the thread anchors
;; to the file itself (GitHub's subject_type=file). The pane lists it
;; ahead of the file's line threads; it carries no line range
(fn M.file-comment [session-id file-path body]
  (let [user-id (with-user)
        repo-id (with-repo)
        commit-id (with-commit repo-id)
        thread-id (db sqlite.thread :insert
                      {:session_id session-id
                       :file_path file-path
                       :anchor_commit commit-id
                       :status :open
                       :type :file
                       :kind :local
                       :created_by user-id})]
    (db sqlite.comments :insert
        {:thread_id thread-id
         :author_id user-id
         :body (sql-literal body)
         :source :user
         :commit_id commit-id})))

;; ── the branch session ──────────────────────────────────
;; ONE session per (repo, branch) — never chosen, never competing:
;; every reader resolves the branch the buffer sits on, every write
;; (annotate) find-or-creates through ensure-session. A session may
;; carry a PR binding (pr_number, stamped by Review) — that is what
;; promotion, PostReview and PullReview gate on

;; the repo row id of a root, without creating one
(fn repo-id-of [root]
  (?. (db sqlite.repo :get {:where {:path root}}) 1 :id))

;; the session row of the branch ?path sits on (the current buffer
;; by default) — nil outside a repo or when the branch has no
;; session yet. Soft-deleted rows read as gone
(fn M.session-for [?path]
  (let [root (git.repo-root ?path)
        branch (when root (git.branch-name ?path))]
    (when (and root branch)
      (let [repo-id (repo-id-of root)]
        (when repo-id
          (?. (sqlite.active-rows (db sqlite.session :get
                                      {:where {:repo_id repo-id : branch}}))
              1))))))

;; the one and only session per (repo, branch) — private to
;; ensure-session, and backed by the session_live_branch index (see
;; singleton.fnl). The PR binding (if any) is a separate stamp —
;; set-session-pr
(fn create-session []
  (db sqlite.session :insert {:branch (git.branch-name) :repo_id (with-repo)}))

;; find-or-create the current branch's session — the write path
;; (annotate) and Review resolve through here
(fn M.ensure-session []
  (or (?. (M.session-for) :id)
      ;; a detached HEAD has no branch to tie a session to
      (when (and (git.repo-root) (git.branch-name))
        (create-session))))

;; bind a session to a PR — the branch's session becomes that PR's
;; review. Review binds once: re-binding to another PR is refused
;; there (review-mode's open-pr), since the session's threads belong
;; to the PR they were pulled from and promoted for
(fn M.set-session-pr [session-id pr-number]
  (db sqlite.session :update
      {:set {:pr_number pr-number} :where {:id (or session-id 0)}}))

;; soft-deleted sessions read as gone everywhere: the listings, the
;; outboxes and PR-binding reads all resolve through here
(fn M.session-by-id [id]
  (when id
    (?. (sqlite.active-rows (db sqlite.session :get {:where {: id}})) 1)))

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

;; one pulled PR comment that seeds a thread — subject_type "file" is
;; a whole-file comment (no lines, never outdated); for line threads
;; position null means outdated (the PR moved past its line), anchor
;; best-effort at original_line and flag the thread
(fn M.import-thread [session-id item]
  (let [repo-id (with-repo)
        login (?. item :user :login)
        file? (= :file item.subject_type)
        line (when (not file?) (or item.line item.original_line 1))
        commit-id (with-commit repo-id item.commit_id)
        thread-id (db sqlite.thread :insert
                      {:session_id session-id
                       :file_path item.path
                       :line_start line
                       :line_end line
                       :anchor_commit commit-id
                       :status :open
                       :type (if file? :file :line)
                       :kind :review
                       :gh_outdated (when (and (not file?) (not item.position))
                                      1)
                       :created_by (M.with-gh-user login)})]
    (db sqlite.comments :insert
        {:thread_id thread-id
         :author_id (M.with-gh-user login)
         :body (sql-literal item.body)
         :source :github
         :commit_id commit-id
         :gh_comment_id (tostring item.id)})
    thread-id))

;; one pulled PR comment joining an existing thread (in_reply_to)
(fn M.import-comment [thread-id item]
  (db sqlite.comments :insert
      {:thread_id thread-id
       :author_id (M.with-gh-user (?. item :user :login))
       :body (sql-literal item.body)
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
                            :code_snapshot (sql-literal t.code_snapshot)
                            :anchor_commit t.anchor_commit
                            :status :open
                            :type (or t.type :line)
                            :kind :local
                            :parent_id t.id
                            :created_by (with-user (?. (session-repo t.session_id)
                                                       :path))})]
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
        (let [repo (session-repo t.session_id)
              me (with-user (?. repo :path))
              commit-id (with-commit (?. repo :id)
                          (or ?anchor-sha (M.commit-sha t.anchor_commit)))
              twin-id (db sqlite.thread :insert
                          {:session_id (or ?session-id t.session_id)
                           :file_path t.file_path
                           :line_start t.line_start
                           :line_end t.line_end
                           :code_snapshot (sql-literal t.code_snapshot)
                           :anchor_commit commit-id
                           :status :open
                           :type (or t.type :line)
                           :kind :review
                           :parent_id t.id
                           :created_by me})]
          (db sqlite.comments :insert
              {:thread_id twin-id
               :author_id me
               :body (sql-literal body)
               :source :user
               :commit_id commit-id})
          twin-id))))

;; rewrite one comment's body in place — the pane's e key refines a
;; promoted (still unposted) comment without touching anything else
(fn M.update-comment-body [comment-id body]
  (db sqlite.comments :update
      {:set {:body (sql-literal body)} :where {:id (or comment-id 0)}}))

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
                 :body (sql-literal body)
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
             :author_id (with-user (?. (session-repo thread.session_id) :path))
             :body (sql-literal body)
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
  (let [me (with-user (?. (session-repo (?. (thread-by-id thread-id)
                                            :session_id))
                          :path))]
    (icollect [_ c (ipairs (M.comments-for (or thread-id 0)))]
      (when (mine-unflagged? c me :posted) c))))

;; unsent user messages of the session's logical threads, either half
;; — the flush outbox; one entry per comment, grouped per thread by
;; the caller
(fn M.pending-for-flush [session-id]
  (if (not session-id)
      []
      (let [me (with-user (?. (session-repo session-id) :path))
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
      (let [me (with-user (?. (session-repo session-id) :path))
            out []]
        (each [_ t (ipairs (M.review-rows-for-session session-id))]
          (each [_ c (ipairs (M.comments-for (or t.id 0)))]
            (when (mine-unflagged? c me :posted)
              (table.insert out {:thread t :comment c}))))
        out)))

(fn M.mark-annotations [flag ids]
  (when (vim.tbl_contains [:sent :posted] flag)
    (db-with-open (fn [d]
                    (each [_ id (ipairs ids)]
                      (d:execute (string.format "update comment set %s = 1 where id = %d"
                                                (tostring flag) (or id 0))))))))

;; hard-delete one of the session's own comments — only ever a local
;; draft: user-sourced, never sent, never posted, no github id — so
;; nothing the agent or github has seen can disappear through here
(fn M.delete-comment [comment-id]
  (let [c (?. (db sqlite.comments :get {:where {:id (or comment-id 0)}}) 1)]
    (when (and c (= :user (or c.source :user)) (= 0 (or c.sent 0))
               (= 0 (or c.posted 0)) (not c.gh_comment_id))
      (db-with-open (fn [d]
                      (d:execute (string.format "delete from comment where id = %d"
                                                (or c.id 0)))))
      true)))

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
;; shows there). The pane and the flush all walk this;
;; a soft-deleted session reads as empty
(fn M.threads-for-session [session-id]
  (if (not (M.session-by-id session-id))
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
;; pulled threads in the session they were imported to; a
;; soft-deleted session reads as empty
(fn M.review-rows-for-session [session-id]
  (if (not (M.session-by-id session-id))
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

;; delete a session the soft way: deleted_at, and because every
;; reader resolves through session-by-id, its threads and comments
;; vanish from every listing and outbox while the rows stay —
;; terminating a set of comments without destroying history, and
;; leaving cross-session pairs untouched by construction
(fn M.delete-session [session-id]
  (db sqlite.session :update
      {:set {:deleted_at (os.time)} :where {:id (or session-id 0)}})
  ;; gh_comment_id is unique table-wide, so the dead session would
  ;; otherwise keep holding the PR's comment ids: a re-Review could
  ;; never pull them into the branch's next session
  (db-with-open (fn [d]
                  (d:execute (string.format "update comment set gh_comment_id = null
                                             where thread_id in (select id from comment_thread
                                                                 where session_id = %d)"
                                            (or session-id 0))))))

M
