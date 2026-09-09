;; [nfnl] codeboomer/sidebar.fnl
;; The review-comments side pane: a plain vsplit (no component library —
;; stock windows/buffers/autocmds) that follows the window it was opened
;; from. While the cursor sits inside a comment thread's
;; [line_start, line_end] range the pane shows that thread's comments;
;; the moment the cursor leaves every thread's lines the pane goes blank.
;; Commented ranges are also marked in the followed buffer's gutter
;; (extmark signs) for as long as the pane is open. The pane keeps
;; whatever it last rendered while the cursor is in other windows —
;; only the followed window drives updates.
(global vim vim)

(local review (require :codeboomer.review))

(local M {})

(local augroup-name :codeboomer-review-pane)
(local pane-buf-name :codeboomer://review-comments)
(local extmark-ns (vim.api.nvim_create_namespace :codeboomer-review-pane))
(local pane-width 40)
;; extmark signs render in the sign column — one per commented line
(local sign-text "✎")

(local state {:win nil
              :buf nil
              :code-win nil
              :session-id nil
              :threads nil
              :threads-path nil
              ;; buffer currently carrying gutter marks, so refreshes and
              ;; teardown can clear exactly the right one
              :signs-buf nil
              ;; signcolumn value to restore when the pane closes
              :signcolumn-was nil})

(fn notify [msg level] (vim.schedule #(vim.notify msg level)))

(fn win-valid? [win] (and win (vim.api.nvim_win_is_valid win)))

;; per-thread colors cycle through groups every colorscheme defines, so
;; the tint follows the theme for free; index is the thread's position in
;; the top-to-bottom sorted thread list
(fn thread-hl [index]
  (let [groups [:Title :Special :String :Function]]
    (. groups (+ 1 (% (- index 1) (length groups))))))

;; gutter marks: one extmark with sign_text per line of every thread's
;; range, in the pane's namespace so a single clear wipes them all.
;; Overlapping threads get consecutive symbols (signcolumn is auto:2
;; while the pane is open) with per-thread colors; earlier threads take
;; the leftmost slot via descending priority
(fn place-signs [bufnr threads]
  (when (and bufnr (vim.api.nvim_buf_is_valid bufnr))
    ;; a file switch in the followed window must strip the previous
    ;; buffer's marks — signs only ever decorate one buffer at a time
    (when (and state.signs-buf (vim.api.nvim_buf_is_valid state.signs-buf))
      (vim.api.nvim_buf_clear_namespace state.signs-buf extmark-ns 0 -1))
    (vim.api.nvim_buf_clear_namespace bufnr extmark-ns 0 -1)
    (each [i t (ipairs threads)]
      (let [start (or t.line_start 0)
            finish (or t.line_end start)
            hl (thread-hl i)]
        (for [ln start finish]
          (vim.api.nvim_buf_set_extmark bufnr extmark-ns (- ln 1) 0
                                        {:sign_text sign-text
                                         :sign_hl_group hl
                                         :priority (- 1000 i)}))))
    (set state.signs-buf bufnr)))

;; threads are queried once per file and kept in memory — cursor moves
;; then only do range checks; comment bodies are fetched when a thread is
;; actually entered, not on every move. A cache miss also refreshes the
;; gutter marks (extmarks ride along with line edits on their own).
(fn cached-threads [path bufnr]
  (if (and state.threads (= state.threads-path path))
      state.threads
      (let [threads (if (and state.session-id (not= path ""))
                        (review.threads-for state.session-id path)
                        [])]
        (set state.threads threads)
        (set state.threads-path path)
        (place-signs bufnr threads)
        threads)))

(fn threads-at [path bufnr line]
  (icollect [_ t (ipairs (cached-threads path bufnr))]
    (when (and t.line_start t.line_end (>= line t.line_start) (<= line t.line_end))
      t)))

(fn thread-header [t]
  (string.format "#%d  %s:%s-%s  (%s)"
                 (or t.id 0)
                 (or (vim.fs.basename (or state.threads-path "")) "?")
                 (or t.line_start "?")
                 (or t.line_end "?")
                 (or t.status "open")))

;; one block per thread: a header line (tinted with the thread's gutter
;; color) plus every comment body verbatim; blocks are separated by a
;; rule so overlapping threads read as distinct messages. Header rows
;; come back 1-based with their hl group so update can highlight them
(fn render [threads]
  (let [lines [] headers []]
    (each [i t (ipairs threads)]
      (when (> i 1) (table.insert lines (string.rep "─" pane-width)))
      (table.insert headers {:row (+ (length lines) 1)
                             :hl (thread-hl i)})
      (table.insert lines (thread-header t))
      (each [_ c (ipairs (review.comments-for t.id))]
        (each [_ l (ipairs (vim.split (or c.body "") "\n"))]
          (table.insert lines l))))
    {: lines : headers}))

(fn set-pane-lines [lines]
  (when (and state.buf (vim.api.nvim_buf_is_valid state.buf))
    (let [bo (. vim.bo state.buf)]
      (vim.api.nvim_buf_clear_namespace state.buf extmark-ns 0 -1)
      (set bo.modifiable true)
      (vim.api.nvim_buf_set_lines state.buf 0 -1 false lines)
      (set bo.modifiable false))))

;; the heart of the pane: cursor inside a thread → render its comments,
;; cursor outside every thread → blank buffer
(fn update []
  (when (and (win-valid? state.code-win) state.buf)
    (let [code-buf (vim.api.nvim_win_get_buf state.code-win)
          path (vim.api.nvim_buf_get_name code-buf)
          cursor-row (?. (vim.api.nvim_win_get_cursor state.code-win) 1)
          {: lines : headers} (render (threads-at path code-buf (or cursor-row 0)))]
      (set-pane-lines lines)
      (each [_ h (ipairs headers)]
        (vim.api.nvim_buf_set_extmark state.buf extmark-ns (- h.row 1) 0
                                      {:line_hl_group h.hl})))))

(fn teardown []
  (pcall vim.api.nvim_del_augroup_by_name augroup-name)
  (when (and state.signs-buf (vim.api.nvim_buf_is_valid state.signs-buf))
    (vim.api.nvim_buf_clear_namespace state.signs-buf extmark-ns 0 -1))
  (when (and (win-valid? state.code-win) state.signcolumn-was)
    (let [wo (. vim.wo state.code-win)]
      (pcall #(set wo.signcolumn state.signcolumn-was))))
  (when (win-valid? state.win)
    (pcall vim.api.nvim_win_close state.win true))
  (set state.win nil)
  (set state.buf nil)
  (set state.code-win nil)
  (set state.session-id nil)
  (set state.threads nil)
  (set state.threads-path nil)
  (set state.signs-buf nil)
  (set state.signcolumn-was nil))

;; (re)attach the pane's autocmds — one augroup so teardown clears them
;; all, however the pane or its anchor window dies
(fn attach-autocmds []
  (vim.api.nvim_create_augroup augroup-name {:clear true})
  ;; re-render on cursor moves and buffer switches in the followed window
  (vim.api.nvim_create_autocmd [:CursorMoved :CursorMovedI :BufEnter]
                               {:group augroup-name
                                :callback (fn []
                                            (when (and (win-valid? state.code-win)
                                                       (= (vim.api.nvim_get_current_win)
                                                          state.code-win))
                                              (update)))})
  ;; the anchor window is gone — nothing left to follow
  (vim.api.nvim_create_autocmd :WinClosed
                               {:group augroup-name
                                :pattern (tostring state.code-win)
                                :once true
                                :callback teardown})
  ;; the user closed the pane itself (:q, <C-w>c, ...) — drop state too
  (vim.api.nvim_create_autocmd :WinClosed
                               {:group augroup-name
                                :pattern (tostring state.win)
                                :once true
                                :callback teardown})
  ;; an annotation landed while the pane was open — drop the caches so
  ;; the fresh thread shows up without a toggle cycle
  (vim.api.nvim_create_autocmd :User
                               {:group augroup-name
                                :pattern :CodeboomerAnnotated
                                :callback (fn []
                                            (set state.threads nil)
                                            (set state.threads-path nil)
                                            (let [(ok session-id) (pcall review.active-session-id)]
                                              (set state.session-id (if ok session-id nil)))
                                            (update))}))

(set M.open
     (fn []
       (if (win-valid? state.win)
           (notify "codeboomer: comments pane already open" vim.log.levels.INFO)
           (let [(ok session-id) (pcall review.active-session-id)]
             (if (not ok)
                 (notify (.. "codeboomer: " (tostring session-id)) vim.log.levels.ERROR)
                 (do
                   (set state.session-id session-id)
                   (set state.code-win (vim.api.nvim_get_current_win))
                   (set state.threads nil)
                   (set state.threads-path nil)
                   ;; make room for the gutter marks while the pane is open;
                   ;; the original value goes back on teardown
                   (let [wo (. vim.wo state.code-win)]
                     (set state.signcolumn-was wo.signcolumn)
                     (set wo.signcolumn :auto:2))
                   ;; :vnew — a bare :vsplit would reuse the current
                   ;; buffer in the new window; we need a scratch buffer
                   (vim.cmd (string.format "botright %dvnew" pane-width))
                   (set state.win (vim.api.nvim_get_current_win))
                   (set state.buf (vim.api.nvim_get_current_buf))
                   (let [bo (. vim.bo state.buf)
                         wo (. vim.wo state.win)]
                     (set bo.buftype :nofile)
                     (set bo.swapfile false)
                     (set bo.bufhidden :wipe)
                     (set bo.modifiable false)
                     (pcall vim.api.nvim_buf_set_name state.buf pane-buf-name)
                     (set wo.wrap true)
                     (set wo.linebreak true)
                     (set wo.number false)
                     (set wo.relativenumber false)
                     (set wo.signcolumn :no)
                     (set wo.winfixwidth true))
                   ;; keep the cursor in the code window — the pane is a
                   ;; follower, not a destination
                   (vim.cmd "wincmd p")
                   (attach-autocmds)
                   (update)
                   (when (= state.session-id nil)
                     (notify "codeboomer: no review session yet — Annotate creates one"
                             vim.log.levels.INFO))))))))

(set M.close teardown)

(set M.toggle (fn [] (if (win-valid? state.win) (teardown) (M.open))))

M
