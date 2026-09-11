;; [nfnl] codeboomer/sidebar.fnl
;; The review-comments pane: an EPHEMERAL right-hand split that exists only
;; while the cursor rests (~100 ms) inside a comment thread's
;; [line_start, line_end] range and the feature is toggled on
;; (:Codeboomer Comments). The moment the cursor leaves every thread's
;; lines the split collapses — the pane holds no state of its own, so
;; there is no per-tab registry: at most one pane window exists at any
;; moment and it follows the cursor across windows and tabpages.
;; Gutter markers (✎ extmark signs) are INDEPENDENT of the toggle: they
;; are placed in every loaded buffer carrying threads of the current
;; review session. The whole thread map is loaded once at startup and
;; reloaded whenever a new annotation lands — buffer enters are plain
;; map lookups, never queries.
(global vim vim)

(local review (require :codeboomer.review))

(local M {})

(local augroup-name :codeboomer-review-pane)
(local pane-buf-name "codeboomer://review-comments")
(local extmark-ns (vim.api.nvim_create_namespace :codeboomer-review-pane))
(local pane-width 40)
;; one symbol per commented line — a plain signcolumn=auto always has
;; room for a single mark, so no window options are ever touched
(local sign-text "✎")
;; the cursor must rest this long on a line before the pane reacts, so
;; sweeping across range boundaries doesn't flicker the split
(local rest-ms 100)

;; the :Codeboomer Comments toggle gates the pane only — markers render
;; regardless of it
(var enabled false)
;; the single pane window, nil whenever it is collapsed
(var pane-win nil)
;; session threads grouped by file path — loaded at startup, reloaded on
;; CodeboomerAnnotated
(var threads-by-path {})
(var timer-id nil)

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
;; get their marks from the BufEnter hook
(fn mark-loaded-buffers []
  (each [_ bufnr (ipairs (vim.api.nvim_list_bufs))]
    (when (vim.api.nvim_buf_is_loaded bufnr)
      (let [path (vim.api.nvim_buf_get_name bufnr)
            threads (. threads-by-path path)]
        (when threads (place-marks bufnr threads))))))

;; threads covering a line of a file, straight from the in-memory map
(fn threads-at [path line]
  (icollect [_ t (ipairs (or (. threads-by-path path) []))]
    (when (and t.line_start t.line_end (>= line t.line_start)
               (<= line t.line_end))
      t)))

;; ── the pane ───────────────────────────────────────────────────────

(fn thread-header [base t]
  (string.format "#%d  %s:%s-%s  (%s)" (or t.id 0) base (or t.line_start "?")
                 (or t.line_end "?") (or t.status :open)))

;; one block per covering thread: a header line tinted with the thread's
;; gutter color plus every comment body verbatim, blocks separated by a
;; rule so overlapping threads read as distinct messages. Header rows
;; come back 1-based with their hl group so render-pane can tint them
(fn render [path threads]
  (let [lines []
        headers []
        base (or (vim.fs.basename (or path "")) "?")]
    (each [i t (ipairs threads)]
      (when (> i 1) (table.insert lines (string.rep "─" pane-width)))
      (table.insert headers {:row (+ (length lines) 1)
                             :hl (thread-hl (or (. t :hl-index) i))})
      (table.insert lines (thread-header base t))
      (each [_ c (ipairs (review.comments-for t.id))]
        (each [_ l (ipairs (vim.split (or c.body "") "\n"))]
          (table.insert lines l))))
    {: lines : headers}))

(fn render-pane [path threads]
  (let [buf (vim.api.nvim_win_get_buf pane-win)
        bo (. vim.bo buf)
        {: lines : headers} (render path threads)]
    (vim.api.nvim_buf_clear_namespace buf extmark-ns 0 -1)
    (set bo.modifiable true)
    (vim.api.nvim_buf_set_lines buf 0 -1 false lines)
    (set bo.modifiable false)
    (each [_ h (ipairs headers)]
      (vim.api.nvim_buf_set_extmark buf extmark-ns (- h.row 1) 0
                                    {:line_hl_group h.hl}))))

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
  ;; ever only one, and it lives where the cursor is
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
      (set wo.winfixwidth true))
    ;; keep the cursor in the code window — the pane is a follower, not
    ;; a destination
    (vim.cmd "wincmd p"))
  (render-pane path threads))

;; the pane's whole contract: cursor resting in a thread's range → show
;; that thread's comments; anywhere else → collapse. The pane itself and
;; floating windows (the compose input, fzf) never drive.
(fn check-now []
  (let [win (vim.api.nvim_get_current_win)]
    (when (and (not= win pane-win)
               (= "" (or (?. (vim.api.nvim_win_get_config win) :relative) "")))
      (let [row (?. (vim.api.nvim_win_get_cursor win) 1)
            path (vim.api.nvim_buf_get_name (vim.api.nvim_win_get_buf win))
            threads (threads-at path (or row 0))]
        (if (and enabled (> (length threads) 0))
            (show-pane path threads)
            (hide-pane))))))

;; the debounce: every qualifying event restarts the timer, so only a
;; cursor that actually rests runs the check
(fn schedule-check []
  (when timer-id (vim.fn.timer_stop timer-id))
  (set timer-id (vim.fn.timer_start rest-ms check-now)))

;; load every thread of the session into the map: at startup and again
;; whenever a new annotation is written. NOT on code-buffer writes —
;; extmarks drift along with edits and stay accurate, while the DB's
;; stored line numbers go stale the moment lines shift; re-placing from
;; it would snap marks back to outdated positions.
(fn reload-threads []
  (let [(ok sid) (pcall review.active-session-id)]
    (if ok
        (do
          (set threads-by-path {})
          (each [_ t (ipairs (if sid (review.threads-for-session sid) []))]
            (let [path (or t.file_path "")
                  peers (vim.list_extend (or (. threads-by-path path) []) [t])]
              ;; stamp each thread's 1-based position in its file's
              ;; top-to-bottom list: gutter marks and pane headers both
              ;; tint from this, so a thread keeps one color even when
              ;; the pane shows only a covering subset of the file
              (tset t :hl-index (length peers))
              (tset threads-by-path path peers)))
          (mark-loaded-buffers)
          ;; an open pane may now be showing stale comments
          (schedule-check))
        (vim.schedule #(vim.notify (.. "codeboomer: " (tostring sid))
                                   vim.log.levels.ERROR)))))

;; markers need these hooks regardless of the toggle, so the group is
;; attached once when the module loads and never torn down
(fn attach-autocmds []
  (vim.api.nvim_create_augroup augroup-name {:clear true})
  (vim.api.nvim_create_autocmd :VimEnter
                               {:group augroup-name :callback reload-threads})
  (vim.api.nvim_create_autocmd :BufEnter
                               {:group augroup-name
                                :callback (fn []
                                            ;; a buffer entered after the map
                                            ;; loaded gets its marks from a
                                            ;; plain lookup
                                            (let [path (vim.api.nvim_buf_get_name 0)
                                                  threads (. threads-by-path
                                                             path)]
                                              (when threads
                                                (place-marks 0 threads)))
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
                                :pattern :CodeboomerAnnotated
                                :callback reload-threads}))

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
               (when timer-id
                 (vim.fn.timer_stop timer-id)
                 (set timer-id nil))
               ;; markers stay — they are independent of the toggle
               (hide-pane)))

(set M.toggle (fn [] (if enabled (M.close) (M.open))))

(attach-autocmds)
;; the initial thread-map load: VimEnter covers normal startup; a module
;; loaded after the UI is up (lazy loading) reloads immediately
(when (= 1 vim.v.vim_did_enter) (reload-threads))

M
