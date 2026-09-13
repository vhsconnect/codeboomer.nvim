;; [nfnl] codeboomer/sidebar.fnl
;; The review-comments pane: an EPHEMERAL right-hand split that exists only
;; while the cursor rests (~100 ms) inside a comment thread's
;; [line_start, line_end] range and the feature is toggled on
;; (:Codeboomer Comments). The moment the cursor leaves every thread's
;; lines the split collapses — the pane holds no state of its own, so
;; there is no per-tab registry: at most one pane window exists at any
;; moment and it follows the cursor across windows and tabpages.
;; Gutter markers (▌ extmark signs) are INDEPENDENT of the toggle: they
;; are placed in every loaded buffer carrying threads of the chosen
;; review session. The whole thread map is loaded once at startup and
;; reloaded whenever a new annotation lands or the chosen session
;; changes — buffer enters are plain map lookups, never queries.
;; The pane is not read-only: three buffer-local keys act on what it
;; shows (r composes a reply in the floating input, q resolves, n hops
;; to the file's next thread), and M.enter / :Codeboomer Enter moves
;; the cursor into it.
(global vim vim)

(local review (require :codeboomer.review))
(local input (require :codeboomer.input))
(local git (require :codeboomer.git))

(local M {})

(local augroup-name :codeboomer-review-pane)
(local pane-buf-name "codeboomer://review-comments")
(local extmark-ns (vim.api.nvim_create_namespace :codeboomer-review-pane))
(local pane-width 40)
;; one gitsigns-style vertical bar per commented line — the half-block
;; fills the sign-column cell so consecutive lines read as one solid
;; rule; a plain signcolumn=auto always has room for a single mark, so
;; no window options are ever touched
(local sign-text "▌")
;; the cursor must rest this long on a line before the pane reacts, so
;; sweeping across range boundaries doesn't flicker the split
(local rest-ms 100)

;; the :Codeboomer Comments toggle gates the pane only — markers render
;; regardless of it
(var enabled false)
;; review mode's pane contract: follow the cursor but never collapse —
;; set by codeboomer.review-mode, reset by close
(var sticky false)
;; the single pane window, nil whenever it is collapsed
(var pane-win nil)
;; session threads grouped by file path — loaded at startup, reloaded on
;; CodeboomerAnnotated
(var threads-by-path {})
(var timer-id nil)
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
;; exists; clearing the namespace first makes this idempotent
(fn place-marks [bufnr threads]
  (when (vim.api.nvim_buf_is_valid bufnr)
    (let [line-count (vim.api.nvim_buf_line_count bufnr)
          taken {}]
      (vim.api.nvim_buf_clear_namespace bufnr extmark-ns 0 -1)
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
                                             :sign_hl_group hl}))))))))

;; refresh every buffer that is around right now; buffers entered later
;; get their marks from the BufEnter hook. Buffers with no remaining
;; threads go through place-marks with an empty list, so threads that
;; resolved (soft-deleted) lose their marks too; nofile buffers are
;; skipped — the pane itself shares this namespace for its header tints
(fn normal-buf [bufnr]
  (= "" (or (?. vim.bo bufnr :buftype) "")))

(fn mark-loaded-buffers []
  (each [_ bufnr (ipairs (vim.api.nvim_list_bufs))]
    (when (and (vim.api.nvim_buf_is_loaded bufnr) (normal-buf bufnr))
      (let [path (git.rel-path (vim.api.nvim_buf_get_name bufnr))]
        (place-marks bufnr (or (. threads-by-path path) []))))))

;; threads covering a line of a file, straight from the in-memory map
(fn threads-at [path line]
  (icollect [_ t (ipairs (or (. threads-by-path path) []))]
    (when (and t.line_start t.line_end (>= line t.line_start)
               (<= line t.line_end))
      t)))

;; ── the pane ───────────────────────────────────────────────────────

(fn thread-header [base t]
  (let [status (if (and t.gh_outdated (> (or t.gh_outdated 0) 0))
                   (.. (or t.status :open) ", outdated")
                   (or t.status :open))]
    (string.format "#%d  %s:%s-%s  (%s)" (or t.id 0) base (or t.line_start "?")
                   (or t.line_end "?") status)))

;; one block per covering thread: a header line tinted with the thread's
;; gutter color plus every comment body verbatim, blocks separated by a
;; rule so overlapping threads read as distinct messages. Header rows
;; come back 1-based with their hl group (for render-pane's tint) and
;; their thread (for the in-pane actions)
(fn render [path threads]
  (let [lines []
        headers []
        base (or (vim.fs.basename (or path "")) "?")]
    (each [i t (ipairs threads)]
      (when (> i 1) (table.insert lines (string.rep "─" pane-width)))
      (table.insert headers {:row (+ (length lines) 1)
                             :hl (thread-hl (or (. t :hl-index) i))
                             :thread t})
      (table.insert lines (thread-header base t))
      (each [_ c (ipairs (review.comments-for t.id))]
        (each [_ l (ipairs (vim.split (or c.body "") "\n"))]
          (table.insert lines l))))
    {: lines : headers}))

(fn render-pane [path threads]
  (let [buf (vim.api.nvim_win_get_buf pane-win)
        bo (. vim.bo buf)
        {: lines : headers} (render path threads)]
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
                                    {:line_hl_group h.hl}))))

;; ── in-pane actions ─────────────────────────────────────────────

;; the thread whose block the pane cursor rests in: header rows come
;; back ascending, so the last one at-or-above the cursor wins — a
;; cursor on the ── rule between blocks still belongs to the block above
(fn pane-thread-at [row]
  (var t nil)
  (each [_ h (ipairs pane-header-rows) &until (> h.row row)]
    (set t h.thread))
  t)

;; re-render from the recorded context — needed after in-pane edits
;; because check-now deliberately ignores the pane window, so a focused
;; pane would otherwise stay stale until the cursor moves back to code
(fn refresh-pane []
  (when (and pane-win (vim.api.nvim_win_is_valid pane-win))
    (render-pane pane-path pane-threads)))

;; r — reply to the block under the pane cursor through the same
;; floating compose input Annotate uses; the reply is a plain user
;; comment, so it joins the flush outbox like any annotation
(fn pane-reply []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (input.open {:title (string.format " Reply to thread #%d> " (or t.id 0))
                     :on-submit (fn [lines]
                                  (when (review.user-reply (or t.id 0)
                                                           (table.concat lines
                                                                         "\n"))
                                    (refresh-pane)))}))))

;; q — resolve the block under the pane cursor: resolved threads are
;; soft-deleted, so a reload rebuilds the map (and the marks) without
;; it; the check the reload schedules re-evaluates the pane against
;; the code window, dropping the block or collapsing the pane when
;; nothing covers the line anymore
(fn pane-resolve []
  (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))]
    (if (not t)
        (vim.notify "codeboomer: no thread block under the pane cursor"
                    vim.log.levels.WARN)
        (do
          (review.resolve-thread (or t.id 0))
          (M.reload-threads)))))

;; n — hop to the next thread of the same file (wrapping) in the code
;; window the pane mirrors; focus lands back in the code and the pane
;; follows on its own via the usual rest detection
(fn pane-next []
  (if (not (and pane-source-win (vim.api.nvim_win_is_valid pane-source-win)))
      (vim.notify "codeboomer: the pane has no code window to jump from"
                  vim.log.levels.WARN)
      (let [t (pane-thread-at (?. (vim.api.nvim_win_get_cursor pane-win) 1))
            all (or (. threads-by-path (or pane-path "")) [])
            pos (if t (or (. t :hl-index) 1) 0)
            next-t (?. all (+ 1 (% pos (length all))))
            target (or (?. next-t :line_start) 1)]
        (vim.api.nvim_set_current_win pane-source-win)
        (vim.api.nvim_win_set_cursor pane-source-win [target 0]))))

;; nil the reference BEFORE closing so the WinClosed handler sees
;; nothing left to react to
(fn hide-pane []
  (let [win pane-win]
    (set pane-win nil)
    (when (and win (vim.api.nvim_win_is_valid win))
      (pcall vim.api.nvim_win_close win true))))

;; open (once) or re-render the pane — an already-open pane is updated
;; in place, so hopping between threads doesn't flicker the split
(fn show-pane [path threads]
  ;; a pane left behind in another tabpage is closed first: there is
  ;; ever only one, and it lives where the cursor is — EXCEPT in
  ;; sticky (review mode) panes, which stay put in their review tab
  (when (and (not sticky) pane-win (vim.api.nvim_win_is_valid pane-win)
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
      ;; reply, q resolve, n next thread — plain keys, no prefix
      (vim.keymap.set :n :r pane-reply
                      {:buffer buf :desc "codeboomer: reply to this thread"})
      (vim.keymap.set :n :q pane-resolve
                      {:buffer buf :desc "codeboomer: resolve this thread"})
      (vim.keymap.set :n :n pane-next
                      {:buffer buf :desc "codeboomer: jump to the next thread"}))
    ;; keep the cursor in the code window — the pane is a follower, not
    ;; a destination
    (vim.cmd "wincmd p"))
  (render-pane path threads))

;; the pane's whole contract evaluated for one code window: cursor
;; resting in a thread's range → show that thread's comments; anywhere
;; else → collapse. Shared by the cursor-rest path below and the
;; pane-resident path — after enter/r/q/n the cursor lives in the pane
;; itself, so re-evaluation targets the code window the pane mirrors
(fn evaluate-at [win]
  (let [row (?. (vim.api.nvim_win_get_cursor win) 1)
        path (git.rel-path (vim.api.nvim_buf_get_name (vim.api.nvim_win_get_buf win)))
        threads (threads-at path (or row 0))]
    (if (and enabled (> (length threads) 0))
        (do
          ;; remember the code window the pane mirrors — the
          ;; pane's n key hops back into it
          (set pane-source-win win)
          (show-pane path threads))
        ;; collapsing is the ephemeral pane's contract; the sticky
        ;; (review mode) pane keeps showing the last thread instead
        (when (not sticky)
          (hide-pane)))))

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

;; load every thread of the chosen session into the map: at startup,
;; again whenever a new annotation is written, and whenever the chosen
;; session changes. NOT on code-buffer writes — extmarks drift along
;; with edits and stay accurate, while the DB's stored line numbers go
;; stale the moment lines shift; re-placing from it would snap marks
;; back to outdated positions.
(fn M.reload-threads []
  ;; nothing chosen yet → adopt the sole session when exactly one
  ;; exists, so the common single-session case is marker-visible at
  ;; startup without anyone picking anything
  (when (not (review.current-session-id))
    (review.adopt-sole-session))
  (let [sid (review.current-session-id)]
    (set threads-by-path {})
    (each [_ t (ipairs (if sid (review.threads-for-session sid) []))]
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

;; markers need these hooks regardless of the toggle, so the group is
;; attached once when the module loads and never torn down
(fn attach-autocmds []
  (vim.api.nvim_create_augroup augroup-name {:clear true})
  (vim.api.nvim_create_autocmd :VimEnter
                               {:group augroup-name :callback M.reload-threads})
  (vim.api.nvim_create_autocmd :BufEnter
                               {:group augroup-name
                                :callback (fn []
                                            ;; a buffer entered after the map
                                            ;; loaded gets its marks from a
                                            ;; plain lookup (or loses them,
                                            ;; if its threads resolved)
                                            (when (normal-buf 0)
                                              (let [path (git.rel-path)]
                                                (place-marks
                                                  0 (or (. threads-by-path path)
                                                        []))))
                                            (schedule-check))})
  (vim.api.nvim_create_autocmd [:WinEnter :TabEnter :CursorMoved :CursorMovedI]
                               {:group augroup-name :callback schedule-check})
  ;; a pane closed by hand (:q, <C-w>c, the tab closing, ...) just drops
  ;; the reference; it reopens when the cursor next rests in a range
  (vim.api.nvim_create_autocmd :WinClosed
                               {:group augroup-name
                                :callback (fn [ev]
                                            (when (= pane-win
                                                     (tonumber ev.match))
                                              (set pane-win nil)))})
  (vim.api.nvim_create_autocmd :User
                               {:group augroup-name
                                :pattern [:CodeboomerAnnotated
                                          :CodeboomerSessionChanged
                                          :CodeboomerImported]
                                :callback M.reload-threads}))

(set M.open (fn []
              (if enabled
                  (vim.notify "codeboomer: review pane already active"
                              vim.log.levels.INFO)
                  (do
                    (set enabled true)
                    ;; immediate — an explicit enable needn't wait out
                    ;; the rest delay
                    (check-now)))))

(set M.close (fn []
               (set enabled false)
               (set sticky false)
               (when timer-id
                 (vim.fn.timer_stop timer-id)
                 (set timer-id nil))
               ;; markers stay — they are independent of the toggle
               (hide-pane)))

;; review mode's entry: enable the pane AND make it persistent — it
;; follows the cursor between threads but never collapses while the
;; review is open
(set M.open-sticky (fn []
                     (set enabled true)
                     (set sticky true)
                     (check-now)))

(set M.toggle (fn [] (if enabled (M.close) (M.open))))

;; whether the pane window is currently on screen — introspection for
;; callers and tests
(set M.pane-valid (fn [] (and pane-win (vim.api.nvim_win_is_valid pane-win))))

;; :Codeboomer Enter / <leader>ce — step into the pane. If it is
;; collapsed but the cursor already rests inside a thread range, open
;; it first; either way focus ends up in the pane window. The rest
;; detection ignores the pane itself, so an entered pane stays put
;; until the cursor moves back out to code (n does exactly that)
(set M.enter (fn []
               (when (not (and pane-win (vim.api.nvim_win_is_valid pane-win)))
                 (check-now))
               (if (and pane-win (vim.api.nvim_win_is_valid pane-win))
                   (vim.api.nvim_set_current_win pane-win)
                   (vim.notify "codeboomer: no review thread under the cursor"
                               vim.log.levels.INFO))))

(attach-autocmds)
;; the initial thread-map load: VimEnter covers normal startup; a module
;; loaded after the UI is up (lazy loading) reloads immediately
(when (= 1 vim.v.vim_did_enter) (M.reload-threads))

M
