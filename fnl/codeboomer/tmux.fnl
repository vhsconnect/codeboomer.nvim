(global vim vim)

(local M {})

(fn shell [command]
  (let [handle (io.popen command)
        output (handle:read :*a)]
    (handle:close)
    output))

(local panes-command
       "tmux list-panes -a -F '#{session_name}|#{session_id}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_mode}|#{pane_active}|#{window_active}|#{pane_current_path}'")

(local last-lines-command
       "tmux list-panes -a -F '#{pane_id}' | while read -r p; do printf '%s\\t' \"$p\"; tmux capture-pane -p -t \"$p\" -S -5 -E -1 2>/dev/null | sed -e '/^[[:space:]]*$/d' | tail -n 1; echo; done")

;; {1} is fzf's first field of the highlighted entry — the pane-id
(set M.preview-command "tmux capture-pane -p -t {1} -S -40")

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
]*)|([^|
]*)"
        result (string.gmatch x pattern)]
    (icollect [(session-name session-id window-index pane-index pane-id
                             pane-current-command pane-mode pane-active
                             window-active pane-current-path) result]
      {: session-name
       : session-id
       : window-index
       : pane-index
       : pane-id
       : pane-current-command
       : pane-mode
       : pane-active
       : window-active
       : pane-current-path})))

(fn parse-last-lines [x]
  (let [result {}]
    (each [line (string.gmatch x "[^\n]+")]
      (let [sep (string.find line "\t" 1 true)]
        (when sep
          (tset result (string.sub line 1 (- sep 1))
                (vim.trim (string.sub line (+ sep 1)))))))
    result))

(fn M.list-panes []
  (parse-panes (shell panes-command)))

;; pane-id → the last non-blank line on screen
(fn M.last-lines []
  (parse-last-lines (shell last-lines-command)))

(fn M.pane-by-id [pane-id]
  (accumulate [found nil _ p (ipairs (M.list-panes)) &until found]
    (when (= p.pane-id pane-id) p)))

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

;; paste {text} into {pane} and press Enter — leaving copy mode first,
;; which would otherwise swallow the paste
(fn M.send [pane text]
  (let [pane-id pane.pane-id]
    (when (not= "" (or pane.pane-mode ""))
      (shell (cancel-mode-command pane-id)))
    (paste-text pane-id text)
    (shell (press-key-command pane-id :Enter))))

;; a background window running {argv} in {cwd} — the client stays put. argv is exec'd as-is — tmux
;; skips the shell when the command arrives as several arguments, so
;; nothing needs quoting. Returns the new pane's id, or nil and why
(fn M.new-window [cwd name argv]
  (let [res (: (vim.system (vim.list_extend [:tmux
                                             :new-window
                                             :-d
                                             :-P
                                             :-F
                                             "#{pane_id}"
                                             :-c
                                             cwd
                                             :-n
                                             name
                                             "--"]
                                            argv)
                           {:text true}) :wait)]
    (if (= 0 res.code)
        (vim.trim (or res.stdout ""))
        (values nil (vim.trim (or res.stderr ""))))))

M
