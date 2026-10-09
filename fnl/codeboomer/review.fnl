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

;; every thread starts LOCAL — annotations and the agent's own
;; findings alike: the note is a conversation until promotion
;; deliberately creates the shipping half. Returns the thread id
(fn new-thread [session-id author-id source anchor body]
  (let [commit-id (with-commit (with-repo))
        thread-id (db sqlite.thread :insert
                      (vim.tbl_extend :force anchor
                                      {:session_id session-id
                                       :anchor_commit commit-id
                                       :status :open
                                       :kind :local
                                       :created_by author-id}))]
    (db sqlite.comments :insert
        {:thread_id thread-id
         :author_id author-id
         :body (sql-literal body)
         : source
         :commit_id commit-id})
    thread-id))

(fn line-anchor [file-path line-start line-end code]
  {:file_path file-path
   :line_start line-start
   :line_end line-end
   :code_snapshot (sql-literal code)
   :type :line})

;; a whole-file comment — no lines, no snapshot: the thread anchors
;; to the file itself (GitHub's subject_type=file). The pane lists it
;; ahead of the file's line threads; it carries no line range
(fn file-anchor [file-path]
  {:file_path file-path :type :file})

(fn M.user-comment [session-id file-path line-start line-end code body]
  (new-thread session-id (with-user) :user
              (line-anchor file-path line-start line-end code) body))

(fn M.file-comment [session-id file-path body]
  (new-thread session-id (with-user) :user (file-anchor file-path) body))

(fn M.agent-comment [session-id file-path line-start line-end code body]
  (new-thread session-id (with-agent-user) :agent
              (line-anchor file-path line-start line-end code) body))

(fn M.agent-file-comment [session-id file-path body]
  (new-thread session-id (with-agent-user) :agent (file-anchor file-path) body))

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
;; session yet
(fn M.session-for [?path]
  (let [root (git.repo-root ?path)
        branch (when root (git.branch-name ?path))]
    (when (and root branch)
      (let [repo-id (repo-id-of root)]
        (when repo-id
          (?. (db sqlite.session :get {:where {:repo_id repo-id : branch}}) 1))))))

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

;; a line comment GitHub can no longer place on the PR head (the PR
;; moved past its lines) comes with line null — position stays set,
;; so it cannot tell. File comments have no lines and never outdate
(fn M.gh-outdated? [item]
  (and (not= :file item.subject_type) (= nil item.line)))

;; one pulled PR comment that seeds a thread. A current one anchors at
;; its line on commit_id; an outdated one at original_line on
;; original_commit_id — the only pair still true for it — and is
;; flagged, never moved
(fn M.import-thread [session-id item]
  (let [repo-id (with-repo)
        login (?. item :user :login)
        file? (= :file item.subject_type)
        outdated? (M.gh-outdated? item)
        line-end (when (not file?)
                   (or (if outdated? item.original_line item.line) 1))
        line-start (when line-end
                     (or (if outdated? item.original_start_line
                             item.start_line)
                         line-end))
        commit-id (with-commit repo-id
                               (if outdated? item.original_commit_id
                                   item.commit_id))
        original-commit-id (when item.original_commit_id
                             (with-commit repo-id item.original_commit_id))
        thread-id (db sqlite.thread :insert
                      {:session_id session-id
                       :file_path item.path
                       :line_start line-start
                       :line_end line-end
                       :anchor_commit commit-id
                       :status :open
                       :type (if file? :file :line)
                       :kind :review
                       :gh_outdated (when outdated? 1)
                       :gh_line item.line
                       :gh_original_line item.original_line
                       :gh_original_commit original-commit-id
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
        (?. (db sqlite.thread :get {:where {:parent_id (or t.id 0)}}) 1)
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

;; per-line trailing whitespace dropped, blank edge lines dropped —
;; snapshot comparisons key on content and indentation only
(fn significant [s]
  (let [trimmed (icollect [_ l (ipairs (vim.split (or s "") "\n"))]
                  (l:gsub "[ \t]+$" ""))]
    (var from 1)
    (var to (length trimmed))
    (while (and (<= from to) (= "" (. trimmed from)))
      (set from (+ from 1)))
    (while (and (< from to) (= "" (. trimmed to)))
      (set to (- to 1)))
    (let [out []]
      (for [i from to] (table.insert out (. trimmed i)))
      (table.concat out "\n"))))

;; first differing line, clipped for a notify
(fn clip [s]
  (let [s (or s :<end>)]
    (if (> (length s) 48) (.. (s:sub 1 45) "...") s)))

;; why the thread's snapshot fails to match the file at its own anchor
;; — nil when it matches or the check doesn't apply. Posting ships the
;; thread's line numbers and GitHub resolves them against the anchor
;; commit's content — a snapshot taken after that commit (WIP
;; annotated before it landed, lines shifted since) cannot resolve
;; there and the post dies with "Line could not be resolved".
;; File-scoped threads and unanchored ones have nothing to resolve
;; against — both already have their own posting paths
(fn mismatch-detail [t]
  (if (= :file (or t.type :line)) nil (not t.anchor_commit) nil
      (let [sha (M.commit-sha t.anchor_commit)]
        (if (not sha)
            nil
            (let [out (git.run (git.repo-root) :show
                               (.. sha ":" (or t.file_path "")))]
              (if (not out)
                  (string.format "%s doesn't exist at the anchor"
                                 (or t.file_path "?"))
                  (let [file-lines (vim.split out "\n")
                        line-end (or t.line_end (or t.line_start 1))]
                    (if (< (length file-lines) line-end)
                        (string.format "the anchor has only %d lines — the range runs past its end"
                                       (length file-lines))
                        (let [expected []]
                          (for [i (or t.line_start 1) line-end]
                            (table.insert expected (. file-lines i)))
                          (let [a (significant (table.concat expected "\n"))
                                b (significant (or t.code_snapshot ""))]
                            (if (= a b)
                                nil
                                (let [al (vim.split a "\n")
                                      bl (vim.split b "\n")]
                                  (var at nil)
                                  (local limit
                                         (math.max (length al) (length bl)))
                                  (for [i 1 limit :until at]
                                    (when (not= (. al i) (. bl i))
                                      (set at i)))
                                  (string.format "first difference: anchor has %s, snapshot has %s"
                                                 (clip (. al at))
                                                 (clip (. bl at)))))))))))))))

(fn snapshot-matches? [t] (not (mismatch-detail t)))

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
        (not (snapshot-matches? t))
        (refuse (string.format "codeboomer: thread #%d can't promote — snapshot doesn't match anchor %s in %s: %s; re-annotate at the current state"
                               (or t.id 0)
                               (or (M.commit-sha (or t.anchor_commit 0)) "?")
                               (or t.file_path "?") (mismatch-detail t))
                vim.log.levels.ERROR)
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

;; a thread GitHub stopped placing on the PR head: only the flag
;; changes, its lines and anchor stay where they were imported
(fn M.mark-gh-outdated [thread-id]
  (db sqlite.thread :update
      {:set {:gh_outdated 1} :where {:id (or thread-id 0)}}))

;; the agent's answer joins the CONVERSATION half: a :review target
;; (a pulled thread the agent was asked about) diverts to its local
;; twin, created on demand — the shim's thread ids stay pair-free
;; without the agent ever knowing halves exist
(fn M.agent-reply [thread-id body]
  (let [rows (or (db sqlite.thread :get {:where {:id thread-id}}) [])
        thread (. rows 1)]
    (if (or (not thread) (= thread.status :resolved))
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
    (if (or (not thread) (= thread.status :resolved))
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
;; a deleted session reads as empty
(fn M.threads-for-session [session-id]
  (if (not (M.session-by-id session-id))
      []
      (let [rows (unresolved-rows (or (db sqlite.thread :get
                                          {:where {:session_id session-id}})
                                      []))
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
;; deleted session reads as empty
(fn M.review-rows-for-session [session-id]
  (if (not (M.session-by-id session-id))
      []
      (let [rows (unresolved-rows (or (db sqlite.thread :get
                                          {:where {:session_id session-id
                                                   :kind :review}})
                                      []))]
        (table.sort rows by-file-then-line)
        rows)))

(fn M.comments-for [thread-id]
  (let [rows (or (db sqlite.comments :get {:where {:thread_id thread-id}}) [])]
    (table.sort rows by-created)
    rows))

;; the author row of a comment — flush messages label each conversation
;; entry with a real name (the local user, the agent, github logins)
(fn M.comment-author [c]
  (?. (db sqlite.user :get {:where {:id (or c.author_id 0)}}) 1))

;; a pulled item that is one of MY posted comments come home: stamp
;; its gh id onto the matching local row instead of duplicating.
;; original_line is the line on the commit it was posted against —
;; the row's own anchor — while line drifts with every later push
(fn M.match-posted-comment [session-id item]
  (let [line (or item.original_line item.line)
        file? (= :file item.subject_type)
        want-path (or item.path "")
        want-body (or item.body "")]
    (fn anchored? [r]
      (if file?
          (= :file r.type)
          (and line (>= line (or r.line_start 0)) (<= line (or r.line_end 0)))))

    (var found nil)
    (each [_ r (ipairs (M.review-rows-for-session session-id)) &until found]
      (when (and (= want-path (or r.file_path "")) (anchored? r))
        (each [_ c (ipairs (M.comments-for (or r.id 0))) &until found]
          (when (and (= 1 (or c.posted 0)) (= nil c.gh_comment_id)
                     (= want-body (or c.body "")))
            (set found c)))))
    found))

;; hard-delete a session with its threads and comments. The deletes
;; are explicit rather than left to on_delete: databases created
;; before the references were declared carry no foreign keys, and
;; twins in other sessions are detached by hand for the same reason
(fn M.delete-session [session-id]
  (let [threads (string.format "select id from comment_thread where session_id = %d"
                               (or session-id 0))]
    (db-with-open (fn [d]
                    (d:execute (string.format "begin;
                                               delete from comment where thread_id in (%s);
                                               update comment_thread set parent_id = null
                                                 where parent_id in (%s) and session_id != %d;
                                               delete from comment_thread where session_id = %d;
                                               delete from session where id = %d;
                                               commit;"
                                              threads threads (or session-id 0)
                                              (or session-id 0)
                                              (or session-id 0)))))))

M
