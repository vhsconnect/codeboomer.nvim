;; [nfnl] compis/input.fnl
;; Multi-line editable input: a scratch buffer in a floating window.
;; Like vim.ui.input, but the callback receives a LIST of lines.
(global vim vim)

(local M {})

(fn close-win [win]
  (when (vim.api.nvim_win_is_valid win)
    (vim.api.nvim_win_close win true)))

(fn open [{:on-submit on-submit
           :on-cancel on-cancel
           :title title}]
  (let [buf (vim.api.nvim_create_buf false true)
        bo (. vim.bo buf)
        width (math.floor (* vim.o.columns 0.6))
        height (math.floor (* vim.o.lines 0.3))
        win (vim.api.nvim_open_win buf true
                                   {:relative :editor
                                    :row (math.floor (/ (- vim.o.lines height) 2))
                                    :col (math.floor (/ (- vim.o.columns width) 2))
                                    :width width
                                    :height height
                                    :style :minimal
                                    :border :rounded
                                    :title (or title " Input ")
                                    :title_pos :center})]
    (var submitted? false)
    ;; flag must flip BEFORE closing: WinClosed fires synchronously inside
    ;; nvim_win_close and would otherwise double-invoke as a cancel
    (set bo.bufhidden :wipe)
    (fn finish [cancelled?]
      (let [lines (vim.api.nvim_buf_get_lines buf 0 -1 false)]
        (set submitted? true)
        (close-win win)
        (if cancelled?
            (when on-cancel (on-cancel))
            (when on-submit (on-submit lines)))))
    ;; <CR> submits from either mode; new lines via normal-mode o/O
    (vim.keymap.set [:i :n] :<CR> #(finish false) {:buffer buf})
    (vim.keymap.set [:i :n] :<Esc> #(finish true) {:buffer buf})
    ;; user closed the window some other way (:q, <C-w>c) counts as cancel
    (vim.api.nvim_create_autocmd :WinClosed
                                 {:pattern (tostring win)
                                  :once true
                                  :callback #(when (not submitted?)
                                               (when on-cancel (on-cancel)))})
    (vim.cmd.startinsert)
    win))

(set M.open open)

M
