;; [nfnl] varubrev/input.fnl
;; Multi-line editable input: a scratch buffer in a floating window.
;; Like vim.ui.input, but the callback receives a LIST of lines.
;; There is no cancel and no key intercepts: the ONLY way out is closing
;; the window (:q, <C-w>c, :bd, ...), which submits. <CR> inserts a real
;; newline (insert mode) / opens a line (normal mode); <Esc> behaves
;; exactly like any vim buffer.
(global vim vim)

(local M {})

(fn close-win [win]
  (when (vim.api.nvim_win_is_valid win)
    (vim.api.nvim_win_close win true)))

;; accept both kebab-case (Fennel callers) and snake_case (Lua callers):
;; hyphens survive compilation as string keys, so plugin/varubrev.lua would
;; otherwise need the awkward ["on-submit"] = syntax
(fn open [{: on-submit :on_submit alt-on-submit
           : title}]
  (let [on-submit (or on-submit alt-on-submit)
        buf (vim.api.nvim_create_buf false true)
        bo (. vim.bo buf)
        width (math.floor (* vim.o.columns 0.6))
        height (math.floor (* vim.o.lines 0.3))
        win (vim.api.nvim_open_win buf true
                                   {:relative :editor
                                    :row (math.floor (/ (- vim.o.lines height)
                                                        2))
                                    :col (math.floor (/ (- vim.o.columns width)
                                                        2))
                                    : width
                                    : height
                                    :style :minimal
                                    :border :rounded
                                    :title (or title " Input ")
                                    :title_pos :center})]
    (var submitted? false)
    ;; flag must flip BEFORE closing: WinClosed fires synchronously inside
    ;; nvim_win_close and would otherwise double-submit
    (set bo.bufhidden :wipe)

    (fn finish []
      (let [lines (vim.api.nvim_buf_get_lines buf 0 -1 false)]
        (set submitted? true)
        (close-win win)
        (when on-submit (on-submit lines))))

    ;; no keymaps: the only way out is closing the window (:q, <C-w>c,
    ;; :bd, ...), which submits
    (vim.api.nvim_create_autocmd :WinClosed
                                 {:pattern (tostring win)
                                  :once true
                                  :callback #(when (not submitted?)
                                               (finish))})
    (vim.cmd.startinsert)
    win))

(set M.open open)

M
