(global vim vim)

(local core (require :nfnl.core))
(local config (require :compis.config))
(local input (require :compis.input))
(local state {:pane nil})

(local M {})

(set M.setup (fn [opts]
               (config.setup opts)))

(local promise vim.schedule)
(local sessions-command
       "tmux list-session -F '#{session_name}|#{session_windows}|#{session_attached}'")

(fn schedule-notify [msg level]
  (promise #(vim.notify msg level)))

(fn shell [command]
  (let [handle (io.popen command)
        output (handle:read :*a)]
    (handle:close)
    output))

(local panes-command
       "tmux list-panes -a -F '#{session_name}|#{session_id}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_mode}|#{pane_active}|#{window_active}'")

(fn parse-panes [x]
  (let [pattern "([^|
]*)|([^|
]*)|([^|
]*)|([^|
]*)|([^|
]*)|([^|
]*)|([^|
]*)|([^|
]*)|([^|
]*)"
        result (string.gmatch x pattern)]
    (icollect [(session-name session-id window-index pane-index pane-id
                             pane-current-command pane-mode pane-active
                             window-active) result]
      {: session-name
       : session-id
       : window-index
       : pane-index
       : pane-id
       : pane-current-command
       : pane-mode
       : pane-active
       : window-active})))

(fn parse-sessions [x]
  (icollect [(name windows attached) (string.gmatch x "([^|]*)|([^|]*)|([^|]*)")]
    {: name : windows :session attached}))

(fn paste-text [pane-id text]
  ;; send-keys -l delivers raw LF bytes, which TUI input fields (pi, Claude
  ;; Code, ...) drop — only CR counts as a key — so multi-line text arrived
  ;; without line breaks. Loading a tmux buffer and pasting it with -p wraps
  ;; the text in bracketed-paste control codes (when the app supports them)
  ;; so newlines are inserted literally; -r stops tmux from rewriting LF to
  ;; CR inside the paste; -d deletes the buffer after pasting.
  (let [handle (io.popen (.. "tmux load-buffer -b compis-paste - && "
                             "tmux paste-buffer -p -r -d -b compis-paste -t "
                             pane-id) :w)]
    (handle:write text)
    (handle:close)))

(fn press-key-command [pane-id key]
  (string.format "tmux send-keys -t %s %s" pane-id key))

(fn cancel-mode-command [pane-id]
  (string.format "tmux send-keys -t %s -X cancel" pane-id))

(fn send-keys-to-selected-pane [text]
  (let [pane-id state.pane.pane-id]
    (when (not= "" state.pane.pane-mode)
      (shell (cancel-mode-command pane-id)))
    (paste-text pane-id text)
    (shell (press-key-command pane-id :Enter))))

(fn choose-pane [panes]
  (let [fzf (require :fzf-lua)
        by-display {}
        lines (icollect [_ p (ipairs panes)]
                (let [display (string.format "%s:%s.%s  %-10s %-6s%s"
                                             p.session-name p.window-index
                                             p.pane-index p.pane-current-command
                                             p.pane-id
                                             (if (not= p.pane-mode "")
                                                 (.. "[" p.pane-mode "]")
                                                 ""))]
                  (tset by-display display p)
                  display))]
    (fzf.fzf_exec lines
                  {:prompt "Pick a Pane> "
                   :actions {:default (fn [selected]
                                        (let [pane (. by-display (. selected 1))]
                                          (set state.pane pane)
                                          (schedule-notify (string.format "compis: pane %s (%s:%s.%s) selected"
                                                                          pane.pane-id
                                                                          pane.session-name
                                                                          pane.window-index
                                                                          pane.pane-index)
                                                           vim.log.levels.INFO)))}})))

(set M.ParseSessions (fn [] (parse-sessions (shell sessions-command))))
(set M.ParsePanes (fn [] (parse-panes (shell panes-command))))

(fn concat-list [lines]
  (table.concat lines "\n"))

(fn get-visual-lines [opts]
  (when (= (?. opts :range) 2)
    (let [path (vim.api.nvim_buf_get_name 0)
          (ok region-lines) (pcall vim.fn.getregion (vim.fn.getpos "'<")
                                   (vim.fn.getpos "'>")
                                   {:type (vim.fn.visualmode)})
          lines (if ok (concat-list region-lines)
                    (concat-list (vim.api.nvim_buf_get_lines 0 (- opts.line1 1)
                                                             opts.line2 false)))]
      {: lines :line1 opts.line1 :line2 opts.line2 :file path})))

(fn compose-message [context text]
  (if context
      (.. "regarding " context.file " lines " context.line1 " to "
          context.line2 "\n" context.lines "\n" text)
      text))

(set M.SendKeys (fn [opts]
                  (if state.pane
                      (let [context (get-visual-lines opts)]
                        (input.open {:title " Compis> "
                                     :on-submit (fn [lines]
                                                  (let [text (concat-list lines)]
                                                    (when (not= text "")
                                                      (send-keys-to-selected-pane (compose-message context
                                                                                                   text)))))}))
                      (schedule-notify "compis: no pane selected — run Compis SetPane first"
                                       vim.log.levels.WARN))))

(set M.SetPane
     (fn []
       (choose-pane (parse-panes (shell panes-command)))))

M
