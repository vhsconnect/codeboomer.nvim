;; [nfnl] codeboomer/sidebar.fnl
;; The review-comments pane and its gutter markers. Review mode stamps
;; every worktree buffer with codeboomer_review_side (:new or :old);
;; markers render only in :new buffers, on that stamp alone. The pane
;; is broader: any real file buffer drives it except an :old-stamped
;; one (thread lines belong to the new side) — so a plain working
;; buffer under Annotate/FlushWithDirective opens it too, just without
;; markers.
;; The pane: a right-hand split in the current tabpage, following
;; the cursor (~100 ms rest) between threads — resting inside a
;; thread's [line_start, line_end] range renders its comments; moving
;; off every range keeps the last block on screen (the pane never
;; collapses on its own; :q closes it and resting in a range reopens).
;; At most one pane exists at any moment, in the review's tabpage.
;; Gutter markers (▌ extmark signs) render in every :new review
;; buffer carrying threads of the review session. The whole thread map
;; is loaded when the review opens and reloaded whenever a new
;; annotation lands, the chosen session changes or PR comments are
;; imported — buffer enters are plain map lookups, never queries.
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
;; one gitsigns-style vertical bar per commented line — the half-block
;; fills the sign-column cell so consecutive lines read as one solid
;; rule; a plain signcolumn=auto always has room for a single mark, so
;; no window options are ever touched
(local sign-text "▌")
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

;; the single pane window, nil whenever it is closed
(var pane-win nil)
;; session threads grouped by file path — loaded when a review opens,
;; reloaded on CodeboomerAnnotated / SessionChanged / Imported
(var threads-by-path {})
;; the same threads flattened, file path then top-to-bottom (matching
;; review.threads-for-session's own order) — pane-jump walks this so
;; n/N cross file boundaries instead of stopping at the current one
(var all-threads [])
(var timer-id nil)
;; set by review-mode when a review is the active session, so
;; pane-jump opens a cross-file target in the worktree instead of the
;; plain repo; nil (the default) resolves against the repo root
(var open-path-resolver nil)
(fn M.set-open-path [f] (set open-path-resolver f))

;; set by review-mode while a review is open: the pane's p key reads
;; the PR session to create review halves in, the pinned head sha to
;; anchor them at, and the head-side ranges for the off-diff gate;
;; nil (the default) means no review is open and promotion refuses
(var promote-context nil)
(fn M.set-promote-context [f] (set promote-context f))

(fn resolve-open-path [path]
  (or (and open-path-resolver (open-path-resolver path))
      (.. (or (git.repo-root) "") "/" path)))
;; in-pane context, recorded on every render: the code window the pane
;; mirrors and what the pane currently shows — the buffer-local pane
;; keys (r/q/n) act on these without the cursor ever leaving the pane
(var pane-source-win nil)
(var pane-path nil)
(var pane-threads nil)
(var pane-header-rows [])

;; per-thread colors cycle through groups every colorscheme defines, so
;; the tint follows the theme for free; index is the thread's position
;; in the top-to-bottom sorted thread list of its file
(fn thread-hl [index]
  (let [groups [:Title :Special :String :Function]]
    (. groups (+ 1 (% (- index 1) (length groups))))))

;; ── gutter markers ─────────────────────────────────────────────────

;; extmarks live in buffers, so marks can only be placed once a buffer
;; exists; clearing the namespace first makes this idempotent. Only
;; review worktree buffers on the NEW side carry marks — thread line
;; numbers belong to that side, so local working buffers (no stamp)
;; and old-side ones (different lines) render none; a side flip drops
;; the marks by the same gate
(fn place-marks [bufnr threads]
  (when (vim.api.nvim_buf_is_valid bufnr)
    (vim.api.nvim_buf_clear_namespace bufnr extmark-ns 0 -1)
    (when (= :new (?. vim.b bufnr :codeboomer_review_side))
      (let [line-count (vim.api.nvim_buf_line_count bufnr)
            taken {}]
        (each [i t (ipairs threads)]
          (let [start (or t.line_start 0)
                finish (math.min (or t.line_end start) line-count)
                hl (thread-hl (or (. t :hl-index) i))]
            (for [ln start finish]
              ;; one symbol per line even where threads overlap — the
              ;; topmost (earliest) thread's color wins
              (when (not (. taken ln))
                (tset taken ln true)
                (vim.api.nvim_buf_set_extmark bufnr extmark-ns (- ln 1) 0
                                              {:sign_text sign-text
                                               :sign_hl_group hl})))))))))

;; refresh every buffer that is around right now; review buffers
;; entered later get their marks from review-mode's own BufEnter hook
;; (configure-code-buffer), which calls M.mark-buffer. Buffers with no
;; remaining threads go through place-marks with an empty list, so
;; threads that resolved (soft-deleted) lose their marks too; the
;; stamp gate leaves local and nofile buffers alone — the pane itself
;; shares this namespace for its header tints
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

(fn mark-loaded-buffers []
  (each [_ bufnr (ipairs (vim.api.nvim_list_bufs))]
    (when (and (vim.api.nvim_buf_is_loaded bufnr) (normal-buf bufnr))
      (let [path (buf-rel-path bufnr)]
        (place-marks bufnr (or (. threads-by-path path) []))))))

;; the thread covering a line of a file, straight from the in-memory
;; map — at most one: overlapping ranges pick the earliest (smallest
;; line_start), the same one place-marks colors the gutter with, so
;; the pane never shows two threads' comments stacked at once
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
                             :unknown)))))

;; conversations also go stale from the outside — the agent shim is a
;; separate process writing the same DB — so a rest re-stamps at most
;; once a second: fresh enough to watch agent answers land, rare
;; enough that the render path stays cheap. The map version moves
;; only when a conversation actually changed, so nothing re-renders
;; for nothing
(local stamp-ttl-ms 1000)
(var last-stamp-ms 0)
(var map-version 0)
(var rendered-sig nil)

(fn conv-sig [t]
  (accumulate [sig "" _ c (ipairs (or t.conversation []))]
    (.. sig (tostring (or c.id 0)) ",")))

(fn maybe-restamp [threads]
  (when (> (- (vim.loop.now) (or last-stamp-ms 0)) stamp-ttl-ms)
    (set last-stamp-ms (vim.loop.now))
    (var changed false)
    (each [_ t (ipairs (or threads []))]
      (let [before (conv-sig t)]
        (stamp-thread t)
        (when (not= before (conv-sig t))
          (set changed true))))
    (when changed
      (set map-version (+ 1 map-version)))))

(fn thread-header [base t]
  (let [status (.. (or t.status :open)
                   (or (when (and t.gh_outdated (> (or t.gh_outdated 0) 0))
                         ", outdated") "")
                   (or (when (= :review (or t.twin-kind :local))
                         " · promoted") ""))]
    (string.format "#%d  %s:%s-%s  (%s)" (or t.id 0) base (or t.line_start "?")
                   (or t.line_end "?") status)))

;; one comment's label — "[source] name", so a conversation reads as
;; who-said-what: [github] logins, [agent] answers, [user] local notes
(fn comment-label [c]
  (string.format "[%s] %s" (or c.source :user) (or c.author-name :unknown)))

;; one block per covering thread: a header line tinted with the
;; thread's gutter color, then every comment as a Comment-tinted
;; label line plus its body verbatim — blank lines separate the
;; header and the comments, so a back-and-forth thread reads as
;; distinct messages instead of one wall. Header and label rows come
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
;; is born in the open PR review's session, anchored at its pinned
;; head, after the off-diff check; the compose input opens prefilled
;; with the annotation's wording unless the pair is virgin (then the
;; annotation ships as-is, no input)
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
        (let [ctx (when promote-context (promote-context))]
          (if (not ctx)
              (vim.notify "codeboomer: no open PR review — :Codeboomer Review first"
                          vim.log.levels.WARN)
              (github.thread-off-diff t ctx.head-ranges)
              (vim.notify "codeboomer: the range falls outside the PR diff — move or resolve the thread first"
                          vim.log.levels.ERROR)
              (let [as-is (virgin-body t)]
                (if as-is
                    (do (review.promote (or t.id 0) as-is ctx.session-id
                                        ctx.head-sha)
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
                                                                  ctx.session-id
                                                                  ctx.head-sha)
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
;; soft-deleted, so a reload rebuilds the map (and the marks) without
;; it. The reload's scheduled check re-evaluates the pane against the
;; code window, but it only re-renders when something covers the row —
;; resolving the LAST thread at the cursor would leave its block
;; stale on screen. Render immediately from whatever still covers the
;; source row (nothing → a blank pane) so the pane always reflects the
;; fresh map; nil (no pane, no source window) skips
(fn covering-at-source []
  (if (not (and pane-source-win (vim.api.nvim_win_is_valid pane-source-win)
                pane-win (vim.api.nvim_win_is_valid pane-win)))
      nil
      (let [buf (vim.api.nvim_win_get_buf pane-source-win)]
        (if (= :old (?. vim.b buf :codeboomer_review_side))
            []
            (let [row (?. (vim.api.nvim_win_get_cursor pane-source-win) 1)]
              (threads-at (or pane-path "") (or row 0)))))))

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
  (maybe-restamp threads)
  (render-pane path threads))

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
;; target (crossing files via resolve-open-path when needed) without
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
                                              pane-source-win))]
                   (vim.api.nvim_win_call pane-source-win
                                          (fn []
                                            (when (not= cur-path target.file_path)
                                              (vim.cmd {:cmd :edit
                                                        :args [(resolve-open-path target.file_path)]}))
                                            (vim.api.nvim_win_set_cursor pane-source-win
                                                                        [(or target.line_start
                                                                             1)
                                                                         0])
                                            (vim.cmd "normal! zz")))
                   (flash-line pane-source-win (or target.line_start 1))
                   (show-pane target.file_path [target])
                   (vim.api.nvim_win_set_cursor pane-win [1 0])))))))

;; called with pane-source-win when re-evaluating from the pane itself
;; (after r/q/n), since the cursor no longer sits in the code window
(fn evaluate-at [win]
  (let [buf (vim.api.nvim_win_get_buf win)
        side (?. vim.b buf :codeboomer_review_side)]
    (when (and (not= side :old) (normal-buf buf))
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

;; load every thread of the chosen session into the map: when a review
;; opens, again whenever a new annotation is written, and whenever the
;; chosen session changes. NOT on code-buffer writes — extmarks drift
;; along with edits and stay accurate, while the DB's stored line
;; numbers go stale the moment lines shift; re-placing from it would
;; snap marks back to outdated positions. (review mode always sets the
;; session before the pane opens, so sid is nil only for stray events)
(fn M.reload-threads []
  (let [sid (review.current-session-id)]
    (set threads-by-path {})
    (set all-threads (if sid (review.threads-for-session sid) []))
    (each [_ t (ipairs all-threads)] (stamp-thread t))
    (set map-version (+ 1 map-version))
    (each [_ t (ipairs all-threads)]
      (let [path (or t.file_path "")
            peers (vim.list_extend (or (. threads-by-path path) []) [t])]
        ;; stamp each thread's 1-based position in its file's
        ;; top-to-bottom list: gutter marks and pane headers both
        ;; tint from this, so a thread keeps one color even when
        ;; the pane shows only a covering subset of the file
        (set t.hl-index (length peers))
        (tset threads-by-path path peers)))
    (mark-loaded-buffers)
    ;; an open pane may now be showing stale comments
    (schedule-check)))

;; the pane's hooks, attached once when the module loads (with review
;; mode, on the first :Codeboomer Review) and never torn down. Marks
;; need none of them: review-mode's own BufEnter drives mark placement
;; via M.mark-buffer, and reload-threads sweeps open buffers itself
(fn attach-autocmds []
  (vim.api.nvim_create_augroup augroup-name {:clear true})
  (vim.api.nvim_create_autocmd :BufEnter
                               {:group augroup-name :callback schedule-check})
  (vim.api.nvim_create_autocmd [:WinEnter :TabEnter :CursorMoved :CursorMovedI]
                               {:group augroup-name :callback schedule-check})
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
                                          :CodeboomerSessionChanged
                                          :CodeboomerImported]
                                :callback M.reload-threads}))

;; place (or clear) ONE buffer's marks from the loaded map — a plain
;; lookup, no queries. Review mode calls this from its own BufEnter
;; (configure-code-buffer) after stamping a review buffer's side: the
;; stamp decides whether marks belong at all
(set M.mark-buffer
     (fn [bufnr]
       (let [path (buf-rel-path bufnr)]
         (place-marks bufnr (or (. threads-by-path path) [])))))

;; review mode's entry, called when the review tab opens: load the
;; thread map and evaluate the code window straight away — the rest
;; detection takes over from the first cursor move
(set M.open (fn []
              (M.reload-threads)
              (check-now)))

(attach-autocmds)

M
