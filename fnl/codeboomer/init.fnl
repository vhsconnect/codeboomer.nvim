(global vim vim)

(local config (require :codeboomer.config))
(local input (require :codeboomer.input))
(local directives (require :codeboomer.directives))

(local state {:pane nil :query-parts {}})

(local M {})

(macro with-pan [body]
  `(if state.pane
       ,body
       (choose-pane (parse-panes (shell panes-command)) (fn [] ,body))))

(set M.setup (fn [opts]
               (config.setup opts)))

(local promise vim.schedule)

(fn schedule-notify [msg level]
  (promise #(vim.notify msg level)))

(fn shell [command]
  (let [handle (io.popen command)
        output (handle:read :*a)]
    (handle:close)
    output))

(local panes-command
       "tmux list-panes -a -F '#{session_name}|#{session_id}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_mode}|#{pane_active}|#{window_active}'")

(fn one-off-result [stdout]
  ;; --output-format json wraps the answer in an object; show the .result
  ;; field and fall back to raw output when it isn't JSON
  (let [(ok parsed) (pcall vim.json.decode stdout)]
    (if (and ok (= (type parsed) :table) (. parsed :result))
        (. parsed :result)
        stdout)))

(fn run-one-off [prompt]
  ;; async on purpose: a slow flake build / LLM round-trip must not
  ;; freeze the editor, and a non-zero exit must surface stderr.
  ;; argv comes from config.prompting.one_off_command (folded at setup);
  ;; the composed prompt is appended as the final argument
  (let [cmd (?. config :config :prompting :one_off_command)]
    (if cmd
        (vim.system (vim.list_extend (vim.list_slice cmd) [prompt])
                    {:text true :timeout 60000}
                    (fn [obj]
                      (promise #(if (= obj.code 0)
                                    (vim.notify (one-off-result (or obj.stdout
                                                                    ""))
                                                vim.log.levels.INFO)
                                    (vim.notify (.. "codeboomer: one-off failed (exit "
                                                    obj.code ")\n"
                                                    (or obj.stderr ""))
                                                vim.log.levels.ERROR)))))
        (schedule-notify "codeboomer: prompting.one_off_command not set — call setup() first"
                         vim.log.levels.ERROR))))

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

(fn paste-text [pane-id text]
  ;; send-keys -l delivers raw LF bytes, which TUI input fields (pi, Claude
  ;; Code, ...) drop — only CR counts as a key — so multi-line text arrived
  ;; without line breaks. Loading a tmux buffer and pasting it with -p wraps
  ;; the text in bracketed-paste control codes (when the app supports them)
  ;; so newlines are inserted literally; -r stops tmux from rewriting LF to
  ;; CR inside the paste; -d deletes the buffer after pasting.
  (let [handle (io.popen (.. "tmux load-buffer -b codeboomer-paste - && "
                             "tmux paste-buffer -p -r -d -b codeboomer-paste -t "
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

(fn choose-pane [panes ?then]
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
                                          (schedule-notify (string.format "codeboomer: pane %s (%s:%s.%s) selected"
                                                                          pane.pane-id
                                                                          pane.session-name
                                                                          pane.window-index
                                                                          pane.pane-index)
                                                           vim.log.levels.INFO)
                                          ;; execute callback when passed
                                          (when ?then (?then))))}})))

(fn clear-annotations [] (set state.query-parts {}))

(set M.RunOneOff run-one-off)

(fn concat-list [lines]
  (table.concat lines "\n"))

(fn concat-list-with-format [lines beginning sep end]
  (.. beginning "\n" (table.concat lines (.. sep "\n")) "\n" end "\n"))

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
          context.line2 "\n" context.lines "\n" text "\n")
      text))

(set M.Annotate
     (fn [opts]
       (with-pan (let [context (get-visual-lines opts)]
                   (input.open {:title " Annotate> "
                                :on-submit (fn [lines]
                                             (let [text (concat-list lines)]
                                               (when (not= text "")
                                                 (table.insert state.query-parts
                                                               (compose-message context
                                                                                text)))))})))))

(set M.SendWithDirective
     (fn []
       (with-pan (let [fzf (require :fzf-lua)
                       all-directives (directives.list)
                       lines (icollect [_ d (ipairs all-directives)]
                               d.label)]
                   (fzf.fzf_exec lines
                                 {:prompt "Pick a Directive> "
                                  :actions {:default (fn [selected]
                                                       (let [selected-label (. selected
                                                                               1)
                                                             directive-text (directives.get selected-label)
                                                             annotations (concat-list-with-format state.query-parts
                                                                                                  "==Section Start=="
                                                                                                  "===="
                                                                                                  "==Section End==")]
                                                         (send-keys-to-selected-pane (.. annotations
                                                                                         directive-text
                                                                                         "\n"))
                                                         (clear-annotations)))}})))))

(set M.SendKeys
     (fn [opts]
       (with-pan (let [context (get-visual-lines opts)]
                   (input.open {:title " Codeboomer> "
                                :on-submit (fn [lines]
                                             (let [text (concat-list lines)]
                                               (when (not= text "")
                                                 (send-keys-to-selected-pane (compose-message context
                                                                                              text)))))})))))

(set M.SendKeysOO
     (fn [opts]
       (with-pan (let [context (get-visual-lines opts)]
                   (input.open {:title " one-off (Enter to send)> "
                                :submit-on-enter true
                                :on-submit (fn [lines]
                                             (let [text (concat-list lines)]
                                               (when (not= text "")
                                                 (run-one-off (compose-message context
                                                                               text)))))})))))

(set M.SetPane
     (fn []
       (choose-pane (parse-panes (shell panes-command)))))

M
