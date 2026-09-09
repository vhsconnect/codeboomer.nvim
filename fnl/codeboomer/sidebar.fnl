;; [nfnl] codeboomer/sidebar.fnl
;; The review-comments side pane: a plain vsplit (no component library —
;; stock windows/buffers/autocmds) with one instance per tabpage, the
;; same shape avante.nvim uses for its sidebar registry. While the review
;; is toggled on every tab gets its own pane; within a tab the pane is
;; driven by the tab's active window, so switching splits or tabs keeps
;; the pane working. When the cursor sits inside a comment thread's
;; [line_start, line_end] range the pane shows that thread's comments;
;; the moment it leaves every thread's lines the pane goes blank.
;; Commented ranges are also marked in the driving buffer's gutter
;; (extmark signs, per-thread theme colors) while the review is active.
(global vim vim)

(local review (require :codeboomer.review))

(local M {})

(local augroup-name :codeboomer-review-pane)
;; per-tab suffix keeps buffer names unique when several panes coexist
(local pane-buf-prefix "codeboomer://review-comments/")
(local extmark-ns (vim.api.nvim_create_namespace :codeboomer-review-pane))
(local pane-width 40)
;; extmark signs render in the sign column — one per commented line
(local sign-text "✎")

;; sidebars are keyed by tabpage id; `enabled` is the global review
;; toggle — new tabs spawn their own pane while it is on
(var enabled false)
(local sidebars {})

;; the tabpage currently carrying gutter marks — markers collapse when
;; their tab loses focus and are re-placed on return, so exactly one tab
;; ever shows them (background tabs are invisible anyway)
(var active-tab nil)

(fn notify [msg level]
  (vim.schedule #(vim.notify msg level)))

(fn win-valid? [win] (and win (vim.api.nvim_win_is_valid win)))

;; the sidebar whose pane window is win
(fn owner-of [win]
  (var owner nil)
  (each [_ sb (pairs sidebars)]
    (when (= sb.win win) (set owner sb)))
  owner)

;; floats (the compose input, fzf) must not drive the pane
(fn floating? [win]
  (not= "" (or (?. (vim.api.nvim_win_get_config win) :relative) "")))

;; per-thread colors cycle through groups every colorscheme defines, so
;; the tint follows the theme for free; index is the thread's position in
;; the top-to-bottom sorted thread list
(fn thread-hl [index]
  (let [groups [:Title :Special :String :Function]]
    (. groups (+ 1 (% (- index 1) (length groups))))))

;; strip this sidebar's gutter marks — with only the active tab ever
;; holding marks, releasing is always the last release
(fn release-signs [sb]
  (when (and sb.signs-buf (vim.api.nvim_buf_is_valid sb.signs-buf))
    (vim.api.nvim_buf_clear_namespace sb.signs-buf extmark-ns 0 -1))
  (set sb.signs-buf nil))

;; gutter marks: one extmark with sign_text per line of every thread's
;; range, in the pane's namespace. Only the ACTIVE tab carries marks —
;; entering a tab releases the previous one's and re-places its own, so
;; the gutter is a projection of the focused review context, never
;; hidden state. Overlapping threads get consecutive symbols (signcolumn
;; is auto:2 on driving windows) with per-thread colors; earlier threads
;; take the leftmost slot via descending priority
(fn place-signs [sb bufnr threads]
  (when (and bufnr (vim.api.nvim_buf_is_valid bufnr))
    (release-signs sb)
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
    (set sb.signs-buf bufnr)))

;; threads are queried once per file per sidebar and kept in memory —
;; cursor moves then only do range checks; comment bodies are fetched
;; when a thread is actually entered, not on every move. A cache miss
;; also refreshes the gutter marks (extmarks ride along with line edits
;; on their own).
(fn cached-threads [sb path bufnr]
  (if (and sb.threads (= sb.threads-path path))
      sb.threads
      (let [threads (if (and sb.session-id (not= path ""))
                        (review.threads-for sb.session-id path)
                        [])]
        (set sb.threads threads)
        (set sb.threads-path path)
        (place-signs sb bufnr threads)
        threads)))

(fn threads-at [sb path bufnr line]
  (icollect [_ t (ipairs (cached-threads sb path bufnr))]
    (when (and t.line_start t.line_end (>= line t.line_start)
               (<= line t.line_end))
      t)))

(fn thread-header [base t]
  (string.format "#%d  %s:%s-%s  (%s)" (or t.id 0) base (or t.line_start "?")
                 (or t.line_end "?") (or t.status :open)))

;; one block per thread: a header line (tinted with the thread's gutter
;; color) plus every comment body verbatim; blocks are separated by a
;; rule so overlapping threads read as distinct messages. Header rows
;; come back 1-based with their hl group so update can highlight them
(fn render [sb threads]
  (let [lines []
        headers []
        base (or (vim.fs.basename (or sb.threads-path "")) "?")]
    (each [i t (ipairs threads)]
      (when (> i 1) (table.insert lines (string.rep "─" pane-width)))
      (table.insert headers {:row (+ (length lines) 1) :hl (thread-hl i)})
      (table.insert lines (thread-header base t))
      (each [_ c (ipairs (review.comments-for t.id))]
        (each [_ l (ipairs (vim.split (or c.body "") "\n"))]
          (table.insert lines l))))
    {: lines : headers}))

(fn set-pane-lines [sb lines]
  (when (and sb.buf (vim.api.nvim_buf_is_valid sb.buf))
    (let [bo (. vim.bo sb.buf)]
      (vim.api.nvim_buf_clear_namespace sb.buf extmark-ns 0 -1)
      (set bo.modifiable true)
      (vim.api.nvim_buf_set_lines sb.buf 0 -1 false lines)
      (set bo.modifiable false))))

;; the heart of the pane: cursor inside a thread → render its comments,
;; cursor outside every thread → blank buffer
(fn update [sb win]
  (when (and (win-valid? win) sb.buf (vim.api.nvim_buf_is_valid sb.buf))
    (let [code-buf (vim.api.nvim_win_get_buf win)
          path (vim.api.nvim_buf_get_name code-buf)
          cursor-row (?. (vim.api.nvim_win_get_cursor win) 1)
          threads (threads-at sb path code-buf (or cursor-row 0))
          {: lines : headers} (render sb threads)]
      (set-pane-lines sb lines)
      (each [_ h (ipairs headers)]
        (vim.api.nvim_buf_set_extmark sb.buf extmark-ns (- h.row 1) 0
                                      {:line_hl_group h.hl})))))

;; every window that drives a pane gets room for overlap signs; the
;; sidebar remembers what to restore when the review ends
(fn drive [sb win]
  (let [wo (. vim.wo win)]
    (when (not (. sb.touched-wins win))
      (tset sb.touched-wins win wo.signcolumn))
    (set wo.signcolumn "auto:2"))
  (update sb win))

;; active window of a tab, ignoring the tab's own pane
(fn tab-active-win [tab]
  (when (vim.api.nvim_tabpage_is_valid tab)
    (let [win (vim.api.nvim_tabpage_get_win tab)]
      (when (not (owner-of win)) win))))

(fn resolve-session []
  (let [(ok session-id) (pcall review.active-session-id)]
    (if ok session-id (do
                        (notify (.. "codeboomer: " (tostring session-id))
                                vim.log.levels.ERROR)
                        nil))))

(fn spawn [tab]
  (let [sb {: tab
            :win nil
            :buf nil
            :session-id nil
            :threads nil
            :threads-path nil
            ;; which shared mark set this sidebar currently drives
            :signs-buf nil
            :touched-wins {}}]
    (tset sidebars tab sb)
    sb))

(fn spawn-pane [sb]
  (set sb.session-id (resolve-session))
  ;; :vnew — a bare :vsplit would reuse the current buffer in the new
  ;; window; we need a scratch buffer
  (vim.cmd (string.format "botright %dvnew" pane-width))
  (set sb.win (vim.api.nvim_get_current_win))
  (set sb.buf (vim.api.nvim_get_current_buf))
  (let [bo (. vim.bo sb.buf)
        wo (. vim.wo sb.win)]
    (set bo.buftype :nofile)
    (set bo.swapfile false)
    (set bo.bufhidden :wipe)
    (set bo.modifiable false)
    (pcall vim.api.nvim_buf_set_name sb.buf (.. pane-buf-prefix sb.tab))
    (set wo.wrap true)
    (set wo.linebreak true)
    (set wo.number false)
    (set wo.relativenumber false)
    (set wo.signcolumn :no)
    (set wo.winfixwidth true))
  ;; keep the cursor in the code window — the pane is a follower, not a
  ;; destination
  (vim.cmd "wincmd p")
  (drive sb (vim.api.nvim_get_current_win)))

(fn teardown [sb]
  ;; deregister BEFORE releasing: the pane's WinClosed handler looks
  ;; its owner up and must find nothing left to tear down
  (tset sidebars sb.tab nil)
  (release-signs sb)
  (each [win was (pairs (or sb.touched-wins {}))]
    (when (win-valid? win)
      (let [wo (. vim.wo win)]
        (pcall #(set wo.signcolumn was)))))
  (when (win-valid? sb.win)
    (pcall vim.api.nvim_win_close sb.win true)))

;; window/buffer events route to the current tab's sidebar; pane windows
;; themselves and floats never drive
(fn dispatch []
  (let [win (vim.api.nvim_get_current_win)]
    (when (and (not (owner-of win)) (not (floating? win)))
      (let [sb (. sidebars (vim.api.nvim_get_current_tabpage))]
        ;; sb.win nil = pane still spawning — its own WinEnter must not
        ;; drive it before the anchor exists
        (when (and sb sb.win) (drive sb win))))))

;; a tab entered while the review is on gets (or refreshes) its pane;
;; gutter marks only ever live on the active tab
(fn ensure-current-tab []
  (when enabled
    (let [tab (vim.api.nvim_get_current_tabpage)]
      (when (and active-tab (not= active-tab tab))
        (let [prev (. sidebars active-tab)]
          (when prev (release-signs prev))))
      (set active-tab tab)
      (let [sb (. sidebars tab)]
        (if (and sb (win-valid? sb.win))
            (do
              ;; drop the cache so the drive re-queries and re-places the
              ;; marks this tab now owns — one small query per tab entry
              (set sb.threads nil)
              (set sb.threads-path nil)
              (let [win (vim.api.nvim_get_current_win)]
                (when (not (owner-of win)) (drive sb win))))
            (do
              (when sb (teardown sb))
              (spawn-pane (spawn tab))))))))

;; fresh annotations land while panes are open — drop every cache so the
;; new thread shows up without a toggle cycle
(fn refresh-all []
  (let [session-id (resolve-session)]
    (each [_ sb (pairs (vim.tbl_values sidebars))]
      (set sb.session-id session-id)
      (set sb.threads nil)
      (set sb.threads-path nil)
      (let [win (tab-active-win sb.tab)]
        (when win (update sb win))))))

;; one global augroup covers every sidebar; teardown-all clears it
(fn attach-autocmds []
  (vim.api.nvim_create_augroup augroup-name {:clear true})
  (vim.api.nvim_create_autocmd [:WinEnter :BufEnter :CursorMoved :CursorMovedI]
                               {:group augroup-name
                                :callback (fn [] (dispatch))})
  (vim.api.nvim_create_autocmd :TabEnter
                               {:group augroup-name
                                :callback (fn [] (ensure-current-tab))})
  ;; a pane closed by hand (:q, <C-w>c, the tab closing, ...) drops its
  ;; state with it
  (vim.api.nvim_create_autocmd :WinClosed
                               {:group augroup-name
                                :callback (fn [ev]
                                            (let [win (tonumber ev.match)
                                                  sb (and win (owner-of win))]
                                              (when sb (teardown sb))))})
  (vim.api.nvim_create_autocmd :User
                               {:group augroup-name
                                :pattern :CodeboomerAnnotated
                                :callback (fn [] (refresh-all))}))

(set M.open (fn []
              (if enabled
                  (notify "codeboomer: review panes already active"
                          vim.log.levels.INFO)
                  (let [tab (vim.api.nvim_get_current_tabpage)]
                    (attach-autocmds)
                    (set enabled true)
                    (set active-tab tab)
                    (spawn-pane (spawn tab))
                    (when (= (. sidebars tab :session-id) nil)
                      (notify "codeboomer: no review session yet — Annotate creates one"
                              vim.log.levels.INFO))))))

(set M.close
     (fn []
       (each [_ sb (pairs (vim.tbl_values sidebars))]
         (teardown sb))
       (set enabled false)
       (set active-tab nil)
       (pcall vim.api.nvim_del_augroup_by_name augroup-name)))

(set M.toggle (fn [] (if enabled (M.close) (M.open))))

M
