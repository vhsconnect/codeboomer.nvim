;; [nfnl] codeboomer/channel.fnl
;; The terminal-buffer half of the pane drivers: tmux panes and nvim
;; terminal buffers implement the same surface — list-panes, last-lines,
;; send, spawn — and every record carries :driver, so the merged picker
;; and the send dispatch treat both alike. A channel pane's process is
;; an nvim job: sends are chansend to the pty, and the codeboomer-agent
;; shim posts back through $NVIM straight into this session (see
;; agent.fnl's rpc). Design notes: docs/terminal-channels.md
(global vim vim)

(local M {})

;; pane-ids are the buffer number prefixed with n — tmux panes use %N —
;; unique in the merged picker and the preview routes on the first char
(local id-prefix :n)

(local preview-lines 40)

;; bufnr → {:label :argv0 :path} for the panes this session started;
;; foreign terminals (a user's own :terminal) are read from the buffer
;; name nvim gives them
(local spawned {})

(fn pane-id [buf]
  (.. id-prefix buf))

(fn pane-buf [pane]
  (or pane.buf (tonumber (string.sub (or pane.pane-id "") 2))))

(fn term-bufs []
  (icollect [_ buf (ipairs (vim.api.nvim_list_bufs))]
    (when (?. vim.b buf :terminal_job_id) buf)))

;; nvim names terminal buffers term://<cwd>//<pid>:<cmd …>; a renamed
;; buffer (ours, a user's) returns the whole name and no cmd
(fn parse-name [name]
  (let [(base cmd) (string.match name "^term://(.*)//%d+:(.*)$")]
    (if base (values base cmd) (values name nil))))

;; the pane record — the tmux pane shape, so pane-display and the pick
;; flow need to know nothing about drivers. session-name :nvim marks it
(fn M.list-panes []
  (icollect [_ buf (ipairs (term-bufs))]
    (let [name (vim.api.nvim_buf_get_name buf)
          (base cmd) (parse-name name)
          own (. spawned buf)]
      {:driver :channel
       :session-name :nvim
       :session-id :nvim
       :window-index :0
       :pane-index (tostring buf)
       :pane-id (pane-id buf)
       :pane-current-command (or (?. own :argv0)
                                 (string.match (or cmd "") "(%S+)")
                                 (or name :term))
       :pane-mode ""
       :pane-active (if (= buf (vim.api.nvim_get_current_buf)) :1 :0)
       :window-active :0
       :pane-current-path (or (?. own :path) (or base (vim.fn.getcwd)))
       : buf
       :chan (?. vim.b buf :terminal_job_id)})))

;; pane-id → the last non-blank line on screen — what the picker shows
(fn last-line [buf]
  (let [lines (vim.api.nvim_buf_get_lines buf 0 -1 false)]
    (var out "")
    (for [i (length lines) 1 -1 &until (not= out "")]
      (when (= out "")
        (set out (vim.trim (. lines i)))))
    out))

(fn M.last-lines []
  (let [result {}]
    (each [_ p (ipairs (M.list-panes))]
      (tset result p.pane-id (last-line p.buf)))
    result))

;; paste {text} into the terminal behind {pane} and press Enter —
;; wrapped in bracketed paste so TUI input fields (pi, Claude Code, …)
;; take the newlines literally; the same trick as tmux's paste-buffer
;; -p, delivered as raw bytes to the pty. One difference: nvim exposes
;; no query for whether the child enabled mode 2004 (tmux checks), so
;; the wrap is unconditional — targets that ignore bracketed paste
;; will show the wrap's control codes
(fn M.send [pane text]
  (let [buf (pane-buf pane)
        chan (when (and buf (vim.api.nvim_buf_is_valid buf))
               (?. vim.b buf :terminal_job_id))]
    (if chan
        (vim.fn.chansend chan (.. "\027[200~" text "\027[201~\r"))
        (values nil "the terminal behind that pane is gone"))))

;; a terminal buffer in its own right-hand split running {argv} in
;; {cwd}, named {name} — the user's cursor stays where it was. Returns
;; the pane record, or nil and why
(fn M.spawn [cwd name argv]
  (let [back (vim.api.nvim_get_current_win)
        buf (vim.api.nvim_create_buf false true)]
    (vim.cmd "botright vsplit")
    (let [split (vim.api.nvim_get_current_win)]
      (vim.api.nvim_win_set_buf split buf)
      ;; termopen RAISES on a missing executable — a failed launch is a
      ;; reported outcome here, not an error
      (let [(ok chan) (pcall vim.fn.termopen argv {: cwd})]
        (if (and ok (> (or chan -1) 0))
            (do
              ;; the label is the picker's handle; a relaunch of the same
              ;; name falls back to buffer-number suffixing
              (when (not (pcall vim.api.nvim_buf_set_name buf name))
                (pcall vim.api.nvim_buf_set_name buf (.. name "-" buf)))
              (tset spawned buf {:label name :argv0 (. argv 1) :path cwd})
              (vim.api.nvim_set_current_win back)
              {:driver :channel
               :session-name :nvim
               :session-id :nvim
               :window-index :0
               :pane-index (tostring buf)
               :pane-id (pane-id buf)
               :pane-current-command (. argv 1)
               :pane-mode ""
               :pane-active :0
               :window-active :0
               :pane-current-path cwd
               : buf
               : chan})
            (do
              (vim.api.nvim_set_current_win back)
              (vim.api.nvim_win_close split true)
              (vim.api.nvim_buf_delete buf {:force true})
              (values nil (.. "failed to start " (tostring (. argv 1))))))))))

;; every window currently showing {buf}, across all tabpages — the
;; buffer may sit in none (collapsed), one, or (rare) several
(fn windows-for [buf]
  (let [wins []]
    (each [_ tab (ipairs (vim.api.nvim_list_tabpages))]
      (each [_ w (ipairs (vim.api.nvim_tabpage_list_wins tab))]
        (when (= buf (vim.api.nvim_win_get_buf w))
          (table.insert wins w))))
    wins))

;; :Codeboomer TogglePane — collapse the terminal behind {pane} out of
;; the layout, or bring it back in its right-hand split. The job keeps
;; running either way: closing the window only hides the buffer — the
;; pane stays selected and sends keep reaching the pty. Toggling back
;; in lands the cursor in the terminal. Returns :hidden or :shown, or
;; nil and why
(fn M.toggle [pane]
  (let [buf (pane-buf pane)
        live (and buf (vim.api.nvim_buf_is_valid buf)
                  (?. vim.b buf :terminal_job_id))]
    (if (not live)
        (values nil "the terminal behind that pane is gone")
        (let [wins (windows-for buf)]
          (if (not= 0 (length wins))
              (do
                ;; collapse — every window showing it, so no stray copies;
                ;; pcall because the last window of a tabpage can't close
                (each [_ w (ipairs wins)]
                  (pcall vim.api.nvim_win_close w false))
                :hidden)
              (do
                (vim.cmd "botright vsplit")
                (vim.api.nvim_win_set_buf 0 buf)
                :shown))))))

;; the fzf preview calls this over --remote-expr with the raw pane-id;
;; the tail of the terminal buffer — what capture-pane shows for tmux
;; panes. Multi-line strings survive the round-trip
(fn M.preview [id]
  (let [buf (tonumber (string.match (or id "") (.. "^" id-prefix "(%d+)$")))
        live (and buf (vim.api.nvim_buf_is_valid buf)
                  (?. vim.b buf :terminal_job_id))]
    (if live
        (let [lines (vim.api.nvim_buf_get_lines buf 0 -1 false)
              from (math.max 1 (+ 1 (- (length lines) preview-lines)))]
          (table.concat (vim.list_slice lines from) "\n"))
        "(terminal buffer gone)")))

;; one preview command for the merged picker: {1} is fzf's first field,
;; the pane-id. n-prefixed ids read the buffer through the parent
;; nvim's socket — $NVIM is set for every job nvim spawns, fzf's
;; process included — and tmux ids fall through to capture-pane
(set M.preview-command (.. "p={1}; case \"$p\" in " id-prefix
                           "*) nvim --server \"$NVIM\" --remote-expr "
                           "\"v:lua.require('codeboomer.channel').preview('$p')\" 2>/dev/null "
                           "|| echo '(terminal buffer gone)' ;; "
                           "*) tmux capture-pane -p -t \"$p\" -S -"
                           preview-lines " ;; esac"))

M
