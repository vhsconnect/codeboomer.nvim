(global vim vim)

(local core (require :nfnl.core))
(local config (require :compis.config))
(local provider (require :compis.provider))
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

(fn shell-quote [s]
  (.. "'" (string.gsub s "'" "'\\''") "'"))

(fn send-text-command [pane-id text]
  (string.format "tmux send-keys -t %s -l %s" pane-id (shell-quote text)))

(fn press-key-command [pane-id key]
  (string.format "tmux send-keys -t %s %s" pane-id key))

(fn cancel-mode-command [pane-id]
  (string.format "tmux send-keys -t %s -X cancel" pane-id))

(fn send-keys-to-selected-pane [text]
  (let [pane-id state.pane.pane-id]
    (when (not= "" state.pane.pane-mode)
      (shell (cancel-mode-command pane-id)))
    (shell (send-text-command pane-id text))
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

(set M.SendKeys (fn []
                  (if state.pane
                      (vim.ui.input {:prompt "compis> "}
                                    (fn [input]
                                      (when (and input (not= input ""))
                                        (send-keys-to-selected-pane input))))
                      (schedule-notify "compis: no pane selected — run Compis SetPane first"
                                       vim.log.levels.WARN))))

(set M.SetPane
     (fn []
       (choose-pane (parse-panes (shell panes-command)))))

(set M.ask
     (fn [question]
       (let [system-prompt "You are a helpful assistant. Answer concisely."]
         (provider.complete system-prompt question
                            (fn [result err]
                              (if err
                                  (schedule-notify (.. "compis: " err)
                                                   vim.log.levels.ERROR)
                                  (let [content (provider.extract-content config.config.provider
                                                                          result)]
                                    (if content
                                        (schedule-notify content
                                                         vim.log.levels.INFO)
                                        (schedule-notify "compis: no response content"
                                                         vim.log.levels.WARN)))))))))

M
