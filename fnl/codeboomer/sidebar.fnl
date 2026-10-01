;; [nfnl] codeboomer/sidebar.fnl
;; The review-comments pane. Any real file buffer of the session's
;; branch drives it: entering a file renders EVERY thread of that
;; file straight away, and the cursor-following rest detection
;; (~100 ms) narrows to the covering thread once the cursor settles
;; inside a thread's [line_start, line_end] range; moving off every
;; range keeps the last block on screen (the pane never collapses on
;; its own; :q closes it and resting in a range reopens). At most
;; one pane exists at any moment, in the current tabpage.
;; The whole thread map is loaded when a review opens and reloaded
;; whenever a new annotation lands, the resolved branch session
;; changes or PR comments are imported — buffer enters are plain map
;; lookups, never queries.
;; A cursor completely still for ~5 s re-queries the whole session
;; in one pass — the debounce every cursor move restarts — and the
;; pane re-renders from whatever came back right where it sits: the
;; agent shim and PullReview write the same db from outside this
;; process, so new comments and threads reach the map and the pane
;; without a manual reload or a landing on the thread's line.
;; The pane is not read-only: buffer-local keys act on what it shows
;; (r composes a reply on the thread's REVIEW half — gated behind
;; promotion, a replies to the agent on the local half, p promotes
;; the thread into the posting outbox, e edits the promoted comment,
;; q resolves, n/N hop to the next/previous thread of the whole
;; session without leaving the pane — wrapping at both ends); a
;; dimmed keymap footer under the blocks reminds of them.
;; Window-navigate into it (<C-w> w).
(global vim vim)

(local review (require :codeboomer.review))
(local input (require :codeboomer.input))
(local git (require :codeboomer.git))
(local github (require :codeboomer.github))

(local M {})

(local augroup-name :codeboomer-review-pane)
(local pane-buf-name "codeboomer://review-comments")
(local extmark-ns (vim.api.nvim_create_namespace :codeboomer-review-pane))
(local flash-ns (vim.api.nvim_create_namespace :codeboomer-review-flash))
;; how long n/N's flash on the (possibly unfocused) code line lasts
(local flash-ms 2000)
(local pane-width 40)
;; the dimmed cheat-sheet under the rendered blocks — the keys act on
;; the block the cursor rests in, so a reminder of them belongs in the
;; pane itself
(local pane-keys-footer
  [(.. "── keys " (string.rep "─" (- pane-width 8)))
   "r reply · a agent · p promote"
   "e edit · q resolve · n/N thread"])
;; the cursor must rest this long on a line before the pane reacts, so
;; sweeping across range boundaries doesn't flicker the split
(local rest-ms 100)
;; ... and be completely still this long before the db is queried for
;; new comments and threads — the idle refresh below. The timer is
;; one-shot: it fires at most once per rest, and only a cursor that
;; moves again re-arms it (the trailing debounce the rest detection
;; above shares the arming events of)
(local db-refresh-ms 5000)

;; the single pane window, nil whenever it is closed
(var pane-win nil)
;; session threads grouped by file path — loaded when a review opens,
;; reloaded on CodeboomerAnnotated / SessionReset / Imported and
;; whenever the resolved branch session changes
(var threads-by-path {})
;; the same threads flattened, file path then top-to-bottom (matching
;; review.threads-for-session's own order) — pane-jump walks this so
;; n/N cross file boundaries instead of stopping at the current one
(var all-threads [])
(var timer-id nil)
;; the idle db refresh's timer — restarted by the same events that
;; drive the rest detection, so only a completely still cursor lets
;; it fire
(var db-refresh-timer nil)
;; in-pane context, recorded on every render: the code window the pane
;; mirrors and what the pane currently shows — the buffer-local pane
;; keys (r/q/n) act on these without the cursor ever leaving the pane
(var pane-source-win nil)
(var pane-path nil)
(var pane-threads nil)
(var pane-header-rows [])

;; per-thread colors cycle through groups every colorscheme defines, so
;; the tint follows the theme for free; index is the thread's position
;; in the top-to-bottom sorted thread list of its file — pane headers
;; tint from this
(fn thread-hl [index]
  (let [groups [:Title :Special :String :Function]]
    (. groups (+ 1 (% (- index 1) (length groups))))))

;; a real file buffer — not the pane itself, not a scratch/float
(fn normal-buf [bufnr]
  (= "" (or (?. vim.bo bufnr :buftype) "")))

;; rel-path walks the tree upward (vim.fs.root) — fine once per
;; buffer, not once per cursor rest; buffer ids are unique for the
;; nvim session, so the cache never collides
(var rel-path-cache {})
(fn buf-rel-path [bufnr]
  (or (. rel-path-cache bufnr)
      (let [p (git.rel-path (vim.api.nvim_buf_get_name bufnr))]
        (tset rel-path-cache bufnr p)
        p)))

;; ── the session the pane renders ────────────────────────────
;; Sessions are tied to branches, never chosen: the pane resolves the
;; branch of the code it mirrors — the window the pane follows when
;; the cursor sits in the pane itself, the current window otherwise
;; (nofile buffers — the pane — never resolve). Everything that must
;; work from anywhere (PostReview, PullReview, ResetSession) reads
;; M.session-id for the same resolution

;; the file path the session resolves against, or nil
(fn source-buf-name []
  (let [in-pane (and pane-win (vim.api.nvim_win_is_valid pane-win)
                     (= (vim.api.nvim_get_current_win) pane-win))
        win (if (and in-pane
                     pane-source-win
                     (vim.api.nvim_win_is_valid pane-source-win))
                pane-source-win
                (vim.api.nvim_get_current_win))
        buf (vim.api.nvim_win_get_buf win)]
    (when (normal-buf buf) (vim.api.nvim_buf_get_name buf))))

;; the branch session row of the code the pane mirrors — nil outside
;; a repo or when the branch has no session yet
(fn source-session []
  (let [name (source-buf-name)]
    (when name (review.session-for name))))

;; the same resolution as an id — exported for review-mode and init
(set M.session-id (fn [] (?. (source-session) :id)))

;; the thread covering a line of a file, straight from the in-memory
;; map — at most one: overlapping ranges pick the earliest (smallest
;; line_start), the same one the pane header tints, so the pane never
;; shows two threads' comments stacked at once
(fn threads-at [path line]
  (var found nil)
  (each [_ t (ipairs (or (. threads-by-path path) [])) &until found]
    (when (and t.line_start t.line_end (>= line t.line_start)
               (<= line t.line_end))
      (set found t)))
  (if found [found] []))

;; ── the pane ─────────────────────────────────────────────────────

;; the pane renders from STAMPED fields, never live queries: a cursor
;; rest re-runs evaluate-at (the debounce fires for the pane's own
;; window too), and sqlite.lua opens a connection per call — querying
;; per render made navigation sluggish. reload-threads and
;; refresh-pane stamp; render only reads
(fn stamp-thread [t]
  (let [twin (review.twin (or t.id 0))]
    (set t.twin-kind (when twin twin.kind))
    (set t.conversation (review.conversation-comments (or t.id 0)))
    (each [_ c (ipairs (or t.conversation []))]
      (set c.author-name (or (?. (review.comment-author c) :name)
                             :unknown)))
    (set t.anchor-sha (when t.anchor_commit (review.commit-sha t.anchor_commit)))))

;; conversations also go stale from the outside — the agent shim is a
;; separate process writing the same DB — which is what the idle db
;; refresh re-stamps through reload-threads; the map version moves
;; only when the map actually changed, so nothing re-renders for
;; nothing
(var map-version 0)
(var rendered-sig nil)

(fn conv-sig [t]
  (accumulate [sig "" _ c (ipairs (or t.conversation []))]
    (.. sig (tostring (or c.id 0)) ",")))

;; what the pane renders of the map: the threads in order plus each
;; one's conversation — two maps with the same signature render
;; identically, so an idle refresh against a quiet db skips the
;; version bump and with it the re-render
(fn map-sig []
  (accumulate [sig "" _ t (ipairs all-threads)]
    (.. sig (tostring (or t.id 0)) ":" (conv-sig t) ";")))

;; the first 7 chars of a sha, or "?" when there isn't one to show
(fn short-sha [sha]
  (if (and sha (>= (length sha) 7)) (sha:sub 1 7) (or sha "?")))

(fn thread-header [base t]
  (let [status (.. (or t.status :open)
                   (or (when (and t.gh_outdated (> (or t.gh_outdated 0) 0))
                         ", outdated") "")
                   (or (when (= :review (or t.twin-kind :local))
                         " · promoted") ""))
        pos (if (= :file (or t.type :line))
                "file"
                (.. (or t.line_start "?") "-" (or t.line_end "?")))]
    (string.format "#%d  %s:%s  (%s)  anchor %s" (or t.id 0) base
                   pos status
                   (short-sha t.anchor-sha))))$

;; one comment's label — "[source] name", so a conversation reads as
;; who-said-what: [github] logins, [agent] answers, [user] local notes
(fn comment-label [c]
  (string.format "[%s] %s" (or c.source :user) (or c.author-name :unknown)))

;; one block per covering thread: a header line tinted with the
;; thread's color, then every comment as a Comment-tinted label line
;; plus its body verbatim — blank lines separate the header and the
;; comments, so a back-and-forth thread reads as distinct messages
;; instead of one wall. Header and label rows come
;; back 1-based with their hl group (for render-pane's tint) —
;; headers also carry their thread (for the in-pane actions)
(fn render [path threads]
  (let [lines []
        headers []
        labels []
        base (or (vim.fs.basename (or path "")) "?")]
    (each [i t (ipairs threads)]
      (when (> i 1) (table.insert lines (string.rep "─" pane-width)))
      (table.insert headers {:row (+ (length lines) 1)
                             :hl (thread-hl (or (. t :hl-index) i))
                             :thread t})
      (table.insert lines (thread-header base t))
      (table.insert lines "")
      (each [j c (ipairs (or t.conversation []))]
        (when (> j 1) (table.insert lines ""))
        (table.insert labels {:row (+ (length lines) 1)})
        (table.insert lines (comment-label c))
        (each [_ l (ipairs (vim.split (or c.body "") "\n"))]
          (table.insert lines l))))
    ;; the keymap footer rides along whenever anything is shown — an
    ;; empty pane stays blank, so the resolve-to-nothing flow reads
    ;; as before
    (when (> (length threads) 0)
      (table.insert lines "")
      (each [_ l (ipairs pane-keys-footer)]
        (table.insert labels {:row (+ (length lines) 1)})
        (table.insert lines l)))
    {: lines : headers : labels}))

;; same path, same threads, same map version → what is on screen is
;; already right
(fn pane-sig [path threads]
  (.. (or path "") "|" (tostring map-version) "|"
      (table.concat (icollect [_ t (ipairs (or threads []))]
                      (tostring (or t.id 0))) ",")))

(fn render-pane [path threads]
  ;; identical content is already on screen — cursor rests re-run
  ;; evaluate-at and would otherwise rewrite the buffer for nothing
  (when (not= (pane-sig path threads) rendered-sig)
    (set rendered-sig (pane-sig path threads))
    (let [buf (vim.api.nvim_win_get_buf pane-win)
          bo (. vim.bo buf)
          {: lines : headers : labels} (render path threads)]
      ;; remember what is on screen — the pane keys below read it back
      (set pane-path path)
      (set pane-threads threads)
      (set pane-header-rows headers)
      (vim.api.nvim_buf_clear_namespace buf extmark-ns 0 -1)
      (set bo.modifiable true)
      (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
      (set bo.modifiable false)
      (each [_ h (ipairs headers)]
        (vim.api.nvim_buf_set_extmark buf extmark-ns (- h.row 1) 0
                                      {:line_hl_group h.hl}))
      (each [_ l (ipairs labels)]
        (vim.api.nvim_buf_set_extmark buf extmark-ns (- l.row 1) 0
                                      {:line_hl_group :Comment})))))

;; ── in-pane actions ─────────────────────────────────────────────

;; the thread whose block the pane cursor rests in: header rows come
;; back ascending, so the last one at-or-above the cursor wins — a
;; cursor on the ── rule between blocks still belongs to the block above
(fn pane-thread-at [row]
  (var t nil)
  (each [_ h (ipairs pane-header-rows) &until (> h.row row)]
    (set t h.thread))
  t)

;; re-render from the recorded context — needed after in-pane actions
;; because check-now deliberately ignores the pane window, so a focused
;; pane would otherwise stay stale until the cursor moves back to code.
;; Action-time freshness: re-stamp what is on screen and force the
;; render by bumping the map version
(fn refresh-pane []
  (when (and pane-win (vim.api.nvim_win_is_valid pane-win))
    (each [_ t (ipairs (or pane-threads []))] (stamp-thread t))
    (set map-version (+ 1 map-version))
    (render-pane pane-path pane-threads)))

;; the shipping half of the pair shown — nil while the thread is
;; unpromoted. Pulled threads ARE their own review half; fresh local
;; threads need p first
(fn review-half [t]
  (if (= :review (or t.kind :local))
      t
      (let [twin (review.twin (or t.id 0))]
        (when (and twin (= :review (or twin.kind :local))) twin))))

;; r — reply on the review half through the same floating compose
;; input Annotate uses; the key itself is the gate: unpromoted threads
;; refuse with a pointer to p, so nothing reaches the posting outbox
;; by accident
(fn pane-reply []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (let [target (review-half t)]
          (if (not target)
              (vim.notify "codeboomer: thread not promoted — p promotes it first"
                          vim.log.levels.WARN)
              (input.open {:title (string.format " Reply on thread #%d> " (or t.id 0))
                           :on-submit (fn [lines]
                                        (when (review.user-reply (or target.id 0)
                                                                 (table.concat lines
                                                                               "\n"))
                                          (refresh-pane)))}))))))

;; a — reply into the conversation half: your side of the agent
;; discussion, stored on the local thread (created on demand for a
;; pulled one). Structurally never ships
(fn pane-agent-reply []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (let [target (if (= :local (or t.kind :local))
                        t
                        (or (review.twin (or t.id 0))
                            (review.ensure-local-twin (or t.id 0))))]
          (if (not target)
              (vim.notify "codeboomer: could not open the conversation"
                          vim.log.levels.ERROR)
              (input.open {:title (string.format " Reply to the agent on thread #%d> "
                                                 (or t.id 0))
                           :on-submit (fn [lines]
                                        (when (review.user-reply (or target.id 0)
                                                                 (table.concat lines
                                                                               "\n"))
                                          (refresh-pane)))}))))))

;; a virgin pair — one user message, nothing from the agent — has
;; nothing to distill: promotion can take the annotation as-is
(fn virgin-body [t]
  (let [cs (review.conversation-comments (or t.id 0))]
    (when (= 1 (length cs))
      (let [c (. cs 1)]
        (when (= :user (or c.source :user)) (or c.body ""))))))

;; the seed for the promote input: the annotation's own wording —
;; the first message you left in the conversation
(fn first-user-body [t]
  (accumulate [body nil _ c (ipairs (review.conversation-comments (or t.id 0)))]
    (or body (when (= :user (or c.source :user)) (or c.body "")))))

;; p — promote: the one door into the posting outbox. The review half
;; is born in the branch's session (when it is bound to a PR) —
;; anchored at the thread's own
;; commit — after the off-diff check (skipped when no PR diff is
;; loaded); the compose input opens prefilled with the annotation's
;; wording unless the pair is virgin (then the annotation ships
;; as-is, no input)
(fn pane-promote []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (= :review (or t.kind :local))
        (vim.notify "codeboomer: this thread is already on github"
                    vim.log.levels.WARN)
        (review.twin (or t.id 0))
        (vim.notify (string.format "codeboomer: thread #%d already promoted"
                                   (or t.id 0))
                    vim.log.levels.WARN)
        (let [session (source-session)
              ;; required here, not at load: review-mode requires
              ;; this module, and p must work before any review
              ;; command has loaded review-mode (right after a restart)
              ctx ((. (require :codeboomer.review-mode) :promote-context)
                   session)]
          (if (not ctx)
              (vim.notify "codeboomer: this branch's session is not bound to a PR — :Codeboomer Review first"
                          vim.log.levels.WARN)
              (and ctx.head-ranges (github.thread-off-diff t ctx.head-ranges))
              (vim.notify "codeboomer: the range falls outside the PR diff — move or resolve the thread first"
                          vim.log.levels.ERROR)
              (let [as-is (virgin-body t)]
                (if as-is
                    (do (review.promote (or t.id 0) as-is ctx.session-id)
                        (refresh-pane)
                        (vim.notify (string.format "codeboomer: thread #%d promoted"
                                                   (or t.id 0))
                                    vim.log.levels.INFO))
                    (input.open {:title (string.format " Promote thread #%d> "
                                                       (or t.id 0))
                                 :prefill (or (first-user-body t) "")
                                 :on-submit (fn [lines]
                                              (let [body (table.concat lines "\n")]
                                                (when (not= ""
                                                            (vim.trim body))
                                                  (review.promote (or t.id 0) body
                                                                  ctx.session-id)
                                                  (refresh-pane)
                                                  (vim.notify (string.format
                                                               "codeboomer: thread #%d promoted"
                                                               (or t.id 0))
                                                              vim.log.levels.INFO))))}))))))))

;; e — refine the promoted comment in place: the oldest still-unposted
;; user message of the review half, rewritten through the same
;; compose input
(fn pane-edit []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (let [target (review-half t)]
          (if (not target)
              (vim.notify "codeboomer: thread not promoted — p promotes it first"
                          vim.log.levels.WARN)
              (let [c (. (review.unposted-user-comments (or target.id 0)) 1)]
                (if (not c)
                    (vim.notify "codeboomer: nothing unposted to edit"
                                vim.log.levels.WARN)
                    (input.open {:title (string.format " Edit comment #%d> "
                                                       (or c.id 0))
                                 :prefill (or c.body "")
                                 :on-submit (fn [lines]
                                              (review.update-comment-body
                                               (or c.id 0)
                                               (table.concat lines "\n"))
                                              (refresh-pane))}))))))))

;; q — resolve the block under the pane cursor: resolved threads are
;; soft-deleted, so a reload rebuilds the map without it. The reload's
;; scheduled check re-evaluates the pane against the
;; code window, but it only re-renders when something covers the row —
;; resolving the LAST thread at the cursor would leave its block
;; stale on screen. Render immediately from whatever still covers the
;; source row (nothing → a blank pane) so the pane always reflects the
;; fresh map; nil (no pane, no source window) skips
(fn covering-at-source []
  (if (not (and pane-source-win (vim.api.nvim_win_is_valid pane-source-win)
                pane-win (vim.api.nvim_win_is_valid pane-win)))
      nil
      (let [row (?. (vim.api.nvim_win_get_cursor pane-source-win) 1)]
        (threads-at (or pane-path "") (or row 0)))))

(fn pane-resolve []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (let [remaining (do
                          (review.resolve-thread (or t.id 0))
                          (M.reload-threads)
                          (covering-at-source))]
          (when remaining
            (render-pane pane-path remaining))))))

;; n/N — hop to the next/previous thread across the WHOLE session
;; (wrapping); the real body sits after show-pane, which it calls
(var pane-jump nil)

;; nil the reference BEFORE closing so the WinClosed handler sees
;; nothing left to react to; the signature dies with the window — a
;; reopened pane must render even when the content would be identical
(fn hide-pane []
  (let [win pane-win]
    (set pane-win nil)
    (set rendered-sig nil)
    (when (and win (vim.api.nvim_win_is_valid win))
      (pcall vim.api.nvim_win_close win true))))

;; open (once) or re-render the pane — an already-open pane is updated
;; in place, so hopping between threads doesn't flicker the split
(fn show-pane [path threads]
  ;; the pane belongs to the current tabpage: one left behind in
  ;; another tab is closed first — there is ever only one
  (when (and pane-win (vim.api.nvim_win_is_valid pane-win)
             (not= (vim.api.nvim_win_get_tabpage pane-win)
                   (vim.api.nvim_get_current_tabpage)))
    (hide-pane))
  (when (not (and pane-win (vim.api.nvim_win_is_valid pane-win)))
    ;; :vnew — a bare :vsplit would reuse the current buffer in the new
    ;; window; we need a scratch buffer
    (vim.cmd (string.format "botright %dvnew" pane-width))
    (set pane-win (vim.api.nvim_get_current_win))
    (let [buf (vim.api.nvim_get_current_buf)
          bo (. vim.bo buf)
          wo (. vim.wo pane-win)]
      (set bo.buftype :nofile)
      (set bo.swapfile false)
      (set bo.bufhidden :wipe)
      (set bo.modifiable false)
      (pcall vim.api.nvim_buf_set_name buf pane-buf-name)
      (set wo.wrap true)
      (set wo.linebreak true)
      (set wo.number false)
      (set wo.relativenumber false)
      (set wo.signcolumn :no)
      (set wo.winfixwidth true)
      ;; in-pane keys exist only in this buffer and die with it: r
      ;; reply (review half), a reply to the agent (local half),
      ;; p promote, e edit the promoted comment, q resolve, n/N
      ;; next/previous thread — plain keys, no prefix
      (vim.keymap.set :n :r pane-reply
                      {:buffer buf :desc "codeboomer: reply on this thread"})
      (vim.keymap.set :n :a pane-agent-reply
                      {:buffer buf
                       :desc "codeboomer: reply to the agent on this thread"})
      (vim.keymap.set :n :p pane-promote
                      {:buffer buf
                       :desc "codeboomer: promote this thread to the PR review"})
      (vim.keymap.set :n :e pane-edit
                      {:buffer buf
                       :desc "codeboomer: edit the promoted comment"})
      (vim.keymap.set :n :q pane-resolve
                      {:buffer buf :desc "codeboomer: resolve this thread"})
      (vim.keymap.set :n :n #(pane-jump 1)
                      {:buffer buf :desc "codeboomer: jump to the next thread"})
      (vim.keymap.set :n :N #(pane-jump -1)
                      {:buffer buf
                       :desc "codeboomer: jump to the previous thread"}))
    ;; keep the cursor in the code window — the pane is a follower, not
    ;; a destination
    (vim.cmd "wincmd p"))
  (render-pane path threads))

;; entering a file loads its comments straight into the pane: every
;; thread of the file stacked top-to-bottom (file-level first), no
;; cursor rest required — the sidebar's own BufEnter hook calls this,
;; so any buffer of the session's branch drives it. A pane already
;; mirroring the file keeps its (possibly cursor-narrowed) view, so
;; window round-trips don't widen it back
(set M.enter-file
     (fn [bufnr]
       (when (and (vim.api.nvim_buf_is_valid bufnr)
                  (normal-buf bufnr))
         (let [path (buf-rel-path bufnr)
               threads (or (. threads-by-path path) [])]
           (when (and (> (length threads) 0)
                      (or (not pane-win)
                          (not (vim.api.nvim_win_is_valid pane-win))
                          (not= path pane-path)))
             (set pane-source-win (vim.api.nvim_get_current_win))
             (show-pane path threads))))))

(fn flash-line [win row]
  (let [buf (vim.api.nvim_win_get_buf win)
        id (vim.api.nvim_buf_set_extmark buf flash-ns (- row 1) 0
                                         {:end_row row :hl_group :IncSearch
                                          :hl_eol true})]
    (vim.defer_fn (fn []
                    (when (vim.api.nvim_buf_is_valid buf)
                      (pcall vim.api.nvim_buf_del_extmark buf flash-ns id)))
                  flash-ms)))

;; stays in the pane: pane-source-win's cursor and buffer move to the
;; target (crossing files via the repo root when needed) without
;; taking focus, the target line flashes there, and the pane re-renders
;; in place — n/N no longer bounce you out to the code window
(set pane-jump
     (fn [dir]
       (if (not (and pane-source-win (vim.api.nvim_win_is_valid pane-source-win)))
           (vim.notify "codeboomer: the pane has no code window to jump from"
                       vim.log.levels.WARN)
           (let [n (length all-threads)]
             (if (= 0 n)
                 (vim.notify "codeboomer: no threads to jump to"
                             vim.log.levels.WARN)
                 (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win)
                                             1))
                       idx (accumulate [found nil i th (ipairs all-threads)]
                             (if (and t (= th.id t.id)) (- i 1) found))
                       target0 (% (+ (or idx (if (> dir 0) -1 0)) dir) n)
                       target (. all-threads (+ target0 1))
                       cur-path (buf-rel-path (vim.api.nvim_win_get_buf
                                              pane-source-win))
                       target-path (.. (or (git.repo-root) "") "/"
                                       target.file_path)]
                   (let [jump-to (fn []
                                   (when (not= cur-path target.file_path)
                                     (vim.cmd {:cmd :edit :args [target-path]}))
                                   ;; line_start can outlive the lines it
                                   ;; pointed at when the file shrinks
                                   (let [row (math.min (or target.line_start 1)
                                                       (vim.api.nvim_buf_line_count 0))]
                                     (vim.api.nvim_win_set_cursor pane-source-win
                                                                  [row 0])
                                     (vim.cmd "normal! zz")
                                     row))
                         row (vim.api.nvim_win_call pane-source-win jump-to)]
                     (flash-line pane-source-win row))
                   (show-pane target.file_path [target])
                   (vim.api.nvim_win_set_cursor pane-win [1 0])))))))

;; called with pane-source-win when re-evaluating from the pane itself
;; (after r/q/n), since the cursor no longer sits in the code window
(fn evaluate-at [win]
  (let [buf (vim.api.nvim_win_get_buf win)]
    (when (normal-buf buf)
      (let [row (?. (vim.api.nvim_win_get_cursor win) 1)
            path (buf-rel-path buf)
            threads (threads-at path (or row 0))]
        (when (> (length threads) 0)
          ;; remember the code window the pane mirrors — the pane's n
          ;; key hops back into it
          (set pane-source-win win)
          (show-pane path threads))))))

;; the cursor-rest entry point: floating windows (the compose input,
;; fzf) never drive
(fn check-now []
  (let [win (vim.api.nvim_get_current_win)]
    (if (= win pane-win)
        (when (and pane-source-win (vim.api.nvim_win_is_valid pane-source-win))
          (evaluate-at pane-source-win))
        (when (= "" (or (?. (vim.api.nvim_win_get_config win) :relative) ""))
          (evaluate-at win)))))

;; the debounce: every qualifying event restarts the timer, so only a
;; cursor that actually rests runs the check
(fn schedule-check []
  (when timer-id (vim.fn.timer_stop timer-id))
  (set timer-id (vim.fn.timer_start rest-ms check-now)))

;; the idle refresh: the same events restart a longer timer too — a
;; cursor completely still for db-refresh-ms queries the db for new
;; comments and threads and reloads the map and pane from
;; whatever came back. Nothing to query without a branch session
(fn idle-refresh []
  (when (M.session-id)
    (M.reload-threads)))

(fn schedule-db-refresh []
  (when db-refresh-timer (vim.fn.timer_stop db-refresh-timer))
  (set db-refresh-timer (vim.fn.timer_start db-refresh-ms idle-refresh)))

;; the fresh rows of whatever the pane is showing — matched by thread
;; id against the just-reloaded map, so the pane's scope survives an
;; idle refresh (a cursor-narrowed pane stays narrowed, a file-wide
;; one stays wide) while its content comes back fresh; rows that
;; vanished (resolved away) drop out, and an empty result blanks the
;; pane
(fn pane-threads-fresh []
  (let [live (or (. threads-by-path (or pane-path "")) [])
        by-id (collect [_ t (ipairs live)] (values t.id t))]
    (icollect [_ t (ipairs (or pane-threads []))]
      (. by-id (or t.id 0)))))

;; the session the map was last loaded from — the resolved branch
;; session is re-read on every reload and compared on every buffer
;; enter, so a branch switch (or a reset, or the first file opened
;; after startup) swaps the map before anything reads it
(var loaded-session-id nil)

;; reload the map when the resolved branch session isn't the one the
;; map was built from — one git call per buffer enter, which is what
;; makes sessions follow branch switches without anyone choosing
;; anything
(fn maybe-reload-session []
  (let [sid (M.session-id)]
    (when (not= sid loaded-session-id)
      (M.reload-threads))))

;; load every thread of the resolved branch session into the map:
;; when a review opens, whenever a new annotation is written, whenever
;; the resolved session changes, and whenever the idle refresh finds
;; the cursor still and the db moved
(fn M.reload-threads []
  (let [sid (M.session-id)
        before (map-sig)]
    (set loaded-session-id sid)
    (set threads-by-path {})
    (set all-threads (if sid (review.threads-for-session sid) []))
    (each [_ t (ipairs all-threads)] (stamp-thread t))
    (each [_ t (ipairs all-threads)]
      (let [path (or t.file_path "")
            peers (vim.list_extend (or (. threads-by-path path) []) [t])]
        ;; stamp each thread's 1-based position in its file's
        ;; top-to-bottom list: pane headers tint from this, so a
        ;; thread keeps one color even when the pane shows only a
        ;; covering subset of the file
        (set t.hl-index (length peers))
        (tset threads-by-path path peers)))
    ;; the pane only re-renders when the db actually moved: an idle
    ;; refresh against a quiet db re-renders nothing
    (when (not= before (map-sig))
      (set map-version (+ 1 map-version))
      ;; an open pane re-renders from the fresh map on the spot — new
      ;; replies land on screen wherever the cursor sits, no landing
      ;; on the thread's line first
      (when (and pane-win (vim.api.nvim_win_is_valid pane-win))
        (render-pane pane-path (pane-threads-fresh)))
      ;; and the cursor-rest check still narrows back to whatever
      ;; covers the cursor
      (schedule-check))))

;; the pane's hooks, attached once when the module loads and never
;; torn down
(fn attach-autocmds []
  (vim.api.nvim_create_augroup augroup-name {:clear true})
  (vim.api.nvim_create_autocmd :BufEnter
                               {:group augroup-name
                                :callback (fn [ev]
                                            ;; the resolved session first:
                                            ;; the map must match the branch
                                            ;; before anyone reads it
                                            (maybe-reload-session)
                                            ;; the file's threads land in
                                            ;; the pane the moment the
                                            ;; file is entered, instead
                                            ;; of waiting for a cursor
                                            ;; rest inside a range
                                            (M.enter-file ev.buf)
                                            (schedule-check)
                                            (schedule-db-refresh))})
  ;; FocusGained too: a branch checked out behind nvim's back (a
  ;; terminal) is picked up on the next focus, once the db refresh
  ;; timer runs
  (vim.api.nvim_create_autocmd [:WinEnter :TabEnter :CursorMoved
                                :CursorMovedI :FocusGained]
                               {:group augroup-name
                                :callback (fn []
                                            (schedule-check)
                                            (schedule-db-refresh))})
  ;; a pane closed by hand (:q, <C-w>c, the tab closing, ...) just drops
  ;; the reference; it reopens when the cursor next rests in a range
  (vim.api.nvim_create_autocmd :WinClosed
                               {:group augroup-name
                                :callback (fn [ev]
                                            (when (= pane-win
                                                     (tonumber ev.match))
                                              (set pane-win nil)
                                              (set rendered-sig nil)))})
  (vim.api.nvim_create_autocmd :User
                               {:group augroup-name
                                :pattern [:CodeboomerAnnotated
                                          :CodeboomerSessionReset
                                          :CodeboomerImported]
                                :callback M.reload-threads}))

;; review mode's entry, called when a review opens: load the thread
;; map and evaluate the code window straight away — the rest
;; detection takes over from the first cursor move
(set M.open (fn []
              (M.reload-threads)
              (check-now)))

(attach-autocmds)

M
