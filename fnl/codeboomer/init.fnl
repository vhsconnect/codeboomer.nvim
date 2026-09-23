(global vim vim)

(local config (require :codeboomer.config))
(local input (require :codeboomer.input))
(local directives (require :codeboomer.directives))
(local review (require :codeboomer.review))

;; autocmds 
(require :codeboomer.sidebar)

(local agent (require :codeboomer.agent))
(local one-offs (require :codeboomer.one-offs))
(local git (require :codeboomer.git))

(local state {:pane nil})

(local M {})

(macro with-pan [body]
  `(if state.pane
       ,body
       (choose-pane (parse-panes (shell panes-command)) (fn [] ,body))))

(fn schedule-notify [msg level]
  (vim.schedule #(vim.notify msg level)))

(set M.setup (fn [opts]
               (config.setup opts)))

(fn shell [command]
  (let [handle (io.popen command)
        output (handle:read :*a)]
    (handle:close)
    output))

(local panes-command
       "tmux list-panes -a -F '#{session_name}|#{session_id}|#{window_index}|#{pane_index}|#{pane_id}|#{pane_current_command}|#{pane_mode}|#{pane_active}|#{window_active}|#{pane_current_path}'")

(local last-lines-command
       "tmux list-panes -a -F '#{pane_id}' | while read -r p; do printf '%s\\t' \"$p\"; tmux capture-pane -p -t \"$p\" -S -5 -E -1 2>/dev/null | sed -e '/^[[:space:]]*$/d' | tail -n 1; echo; done")

(fn one-off-result [stdout]
  ;; --output-format json wraps the answer in an object; show the .result
  ;; field and fall back to raw output when it isn't JSON
  (let [(ok parsed) (pcall vim.json.decode stdout)]
    (if (and ok (= (type parsed) :table) (. parsed :result))
        (. parsed :result)
        stdout)))

(fn run-one-off [cmd prompt]
  (let [argv (vim.list_slice (or cmd.argv []))
        timeout (or cmd.timeout 60000)]
    (vim.system (vim.list_extend argv [prompt]) {:text true : timeout}
                (fn [obj]
                  (vim.schedule #(if (= obj.code 0)
                                     (vim.notify (one-off-result (or obj.stdout
                                                                     ""))
                                                 vim.log.levels.INFO)
                                     (vim.notify (.. "codeboomer: one-off failed (exit "
                                                     obj.code ")\n"
                                                     (or obj.stderr ""))
                                                 vim.log.levels.ERROR)))))))

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

(fn shorten-path [path]
  (let [home (os.getenv :HOME)]
    (if (and home (= 1 (string.find path home 1 true)))
        (.. "~" (string.sub path (+ 1 (length home))))
        path)))

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

(local last-line-max-length 80)

(fn pane-display [p last-line]
  (let [location (string.format "%s:%s.%s" p.session-name p.window-index
                                p.pane-index)
        short-line (if (> (length last-line) last-line-max-length)
                       (.. (string.sub last-line 1 last-line-max-length) "…")
                       last-line)
        mode (if (not= p.pane-mode "") (.. "[" p.pane-mode "] ") "")]
    ;; the pane-id leads the line so the fzf preview can grab it as
    ;; field {1}; it is hidden from the list itself via --with-nth below
    (string.format "%-6s %-11s %-18s %-30s %s%s" p.pane-id
                   p.pane-current-command location
                   (shorten-path p.pane-current-path) mode short-line)))

(local pane-preview-command
       ;; {1} is fzf's first field of the highlighted entry — the pane-id
       "tmux capture-pane -p -t {1} -S -40")

(fn choose-pane [panes ?then]
  (let [fzf (require :fzf-lua)
        last-lines (parse-last-lines (shell last-lines-command))
        by-display {}
        lines (icollect [_ p (ipairs panes)]
                (let [display (pane-display p (. last-lines p.pane-id))]
                  (tset by-display display p)
                  display))]
    (fzf.fzf_exec lines
                  {:prompt "Pick a Pane> "
                   :preview pane-preview-command
                   ;; hide the pane-id from the visible entries — fzf
                   ;; extracts {1} from the original (untransformed) line,
                   ;; so the preview still receives it
                   :fzf_opts {:--with-nth :2..}
                   :winopts {:preview {:wrap false
                                       :layout :vertical
                                       :vertical "down:45%:follow"}}
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

(local one-off-argv-max-length 80)

(fn one-off-display [c]
  (let [argv (table.concat c.argv " ")
        short-argv (if (> (length argv) one-off-argv-max-length)
                       (.. (string.sub argv 1 one-off-argv-max-length) "…")
                       argv)
        ;; surface a non-default timeout so long-running entries stand out
        timeout (if c.timeout
                    (string.format " (%ds)" (math.floor (/ c.timeout 1000)))
                    "")]
    (string.format "%-22s %s%s" c.label short-argv timeout)))

(fn choose-one-off [commands ?then]
  (let [fzf (require :fzf-lua)
        by-display {}
        lines (icollect [_ c (ipairs commands)]
                (let [display (one-off-display c)]
                  (tset by-display display c)
                  display))]
    (fzf.fzf_exec lines
                  {:prompt "Pick a One-off> "
                   :actions {:default (fn [selected]
                                        (let [cmd (. by-display (. selected 1))]
                                          ;; execute callback when passed
                                          (when ?then (?then cmd))))}})))

(local new-session-entry "+ new session")

;; one line per session in the picker: its id, what it reviews (a PR
;; number or "live"), the branch it was created on — the chosen one
;; is starred
(fn session-display [s]
  (let [pr (?. s :pr_number)
        kind (if pr (.. "PR " pr) :live)
        current (if (= s.id (review.current-session-id)) "*" " ")]
    (string.format "%s #%-4d %-9s %s" current (or s.id 0) kind
                   (or s.branch "?"))))

;; d in the session picker — soft-delete a session: its threads and
;; comments vanish from every list and outbox (the rows stay), the
;; way to terminate a set of comments and start fresh. Refuses the
;; open review's session (its worktree and pane still point at it);
;; deleting the chosen one clears the choice, so the next write
;; starts a fresh session (or adopts a sole survivor)
(fn delete-session [s]
  (let [review-mode (require :codeboomer.review-mode)
        info (review-mode.info)]
    (if (and info (= (or s.id 0) (or info.session-id 0)))
        (schedule-notify "codeboomer: close the open review before deleting its session"
                         vim.log.levels.WARN)
        (do
          (review.delete-session (or s.id 0))
          (when (= (or s.id 0) (or (review.current-session-id) -1))
            (review.set-session nil))
          (schedule-notify (string.format "codeboomer: session #%d deleted"
                                          (or s.id 0))
                           vim.log.levels.INFO)))))

;; fzf over the repo's sessions plus a create entry: picking sets the
;; chosen session (the sidebar reloads via CodeboomerSessionChanged)
;; and runs ?then; d deletes the highlighted session in place — the
;; function source re-runs after every reload, so the list always
;; reflects what is left
(fn choose-session [?then]
  (let [fzf (require :fzf-lua)
        by-display {}]
    (fzf.fzf_exec (fn []
                    (let [sessions (or (review.existing-sessions) [])]
                      (each [display (ipairs (vim.tbl_keys by-display))]
                        (tset by-display display nil))
                      (vim.list_extend (icollect [_ s (ipairs sessions)]
                                         (let [display (session-display s)]
                                           (tset by-display display s)
                                           display))
                                       [new-session-entry])))
                  {:prompt "Pick a Session> "
                   :fzf_opts {:--header "enter choose · d delete"}
                   :actions {:default (fn [selected]
                                        (let [choice (. selected 1)
                                              id (if (= choice
                                                        new-session-entry)
                                                     (review.create-session)
                                                     (?. by-display choice :id))]
                                          (review.set-session id)
                                          (schedule-notify (string.format "codeboomer: session #%s chosen"
                                                                          (tostring id))
                                                           vim.log.levels.INFO)
                                          (when ?then (?then))))
                             ;; plain d — shadows typing d into the filter;
                             ;; the list is short enough that it never
                             ;; matters, and the key is worth the prime spot
                             :d {:fn (fn [selected]
                                       (let [s (. by-display
                                                  (. (or selected []) 1))]
                                         (when s (delete-session s))))
                                 :reload true}}})))

;; resolve the session an upcoming write targets: the chosen one when
;; set; otherwise the current branch's own session when one exists
;; (deterministic — never the picker, however many other sessions the
;; repo has on other branches); a fresh one when the repo has none at
;; all; the sole one adopted when exactly one exists on no particular
;; branch match — several unmatched compete → picker
(fn ensure-session [k]
  (let [sid (review.current-session-id)]
    (if sid
        (k)
        (let [branch-match (review.session-for-branch (git.branch-name))]
          (if branch-match
              (do
                (review.set-session branch-match.id)
                (k))
              (let [sessions (or (review.existing-sessions) [])]
                (case (length sessions)
                  0 (do
                      (review.set-session (review.create-session))
                      (k))
                  1 (do
                      (review.set-session (?. sessions 1 :id))
                      (k))
                  _ (choose-session k))))))))

(set M.RunOneOff run-one-off)

(fn concat-list [lines]
  (table.concat lines "\n"))

(fn concat-list-with-format [lines beginning sep end]
  (.. beginning "\n" (table.concat lines (.. sep "\n")) "\n" end "\n"))

(fn get-visual-lines [opts]
  (when (= (?. opts :range) 2)
    (let [path (git.rel-path)
          (ok region-lines) (pcall vim.fn.getregion (vim.fn.getpos "'<")
                                   (vim.fn.getpos "'>")
                                   {:type (vim.fn.visualmode)})
          lines (if ok (concat-list region-lines)
                    (concat-list (vim.api.nvim_buf_get_lines 0 (- opts.line1 1)
                                                             opts.line2 false)))]
      {: lines :line1 opts.line1 :line2 opts.line2 :file path})))

;; with a selection: name the file and the line range; without one:
;; still name the current buffer so the receiving agent knows which file
;; the prompt refers to — raw, unwrapped text is SendSelection's job
(fn compose-message [context text]
  (if context
      (.. "regarding " context.file " lines " context.line1 " to "
          context.line2 "\n" context.lines "\n" text "\n")
      (let [file (git.rel-path)]
        (.. "regarding " file "\n" text "\n"))))

;; one conversation entry — "[source] name: body" — so the receiving
;; agent can tell a GitHub reviewer's words from its own earlier
;; answers and the local user's notes
(fn comment-line [c]
  (let [name (or (?. (review.comment-author c) :name) :unknown)]
    (string.format "[%s] %s: %s" (or c.source :user) name (or c.body ""))))

;; one thread → one message: location and code snapshot, then the FULL
;; conversation (every comment, author-labeled) — a reply flushed to a
;; pulled thread carries the GitHub reviewer's words along, and a
;; thread whose local half carries agent answers ships those answers
;; back for context. Both halves of a pair interleave: the promoted
;; wording and the discussion that produced it
(fn thread-message [t]
  (let [conversation (icollect [_ c (ipairs (review.conversation-comments (or t.id
                                                                              0)))]
                       (comment-line c))]
    (if (= :file (or t.type :line))
        (string.format "regarding %s (thread %s)\n%s"
                       (or t.file_path "?") (or t.id "?")
                       (table.concat conversation "\n\n"))
        (string.format "regarding %s lines %s to %s (thread %s)\n%s\n%s"
                       (or t.file_path "?") (or t.line_start "?")
                       (or t.line_end "?") (or t.id "?") (or t.code_snapshot "") (table.concat conversation
                                                                                          "\n\n")))))

(set M.SetPane
     (fn []
       (choose-pane (parse-panes (shell panes-command)))))

(set M.Sessions (fn []
                  (choose-session)))

(set M.SendPrompt
     (fn [opts]
       (with-pan (let [context (get-visual-lines opts)]
                   (input.open {:title " SendPrompt> "
                                :on-submit (fn [lines]
                                             (let [text (concat-list lines)]
                                               (when (not= text "")
                                                 (send-keys-to-selected-pane (compose-message context
                                                                                              text)))))})))))

;; Raw send
(set M.SendSelection
     (fn [opts]
       (with-pan (let [context (get-visual-lines opts)]
                   (when context
                     (send-keys-to-selected-pane context.lines))))))

(set M.AskOneOff (fn [opts]
                   (let [context (get-visual-lines opts)
                         commands (or (one-offs.list) [])
                         ask (fn [cmd]
                               (input.open {:title (string.format " AskOneOff: %s (Enter to send)> "
                                                                  cmd.label)
                                            :submit-on-enter true
                                            :on-submit (fn [lines]
                                                         (let [text (concat-list lines)]
                                                           (when (not= text "")
                                                             (run-one-off cmd
                                                                          (compose-message context
                                                                                           text)))))}))]
                     (if (= 0 (length commands))
                         (schedule-notify "codeboomer: prompting.one_off_commands not set — call setup() first"
                                          vim.log.levels.ERROR)
                         ;; a single configured command runs directly — the picker only
                         ;; appears when there is an actual choice to make
                         (if (= 1 (length commands))
                             (ask (. commands 1))
                             (choose-one-off commands ask))))))

;; the annotate flow itself — behind the old-side guard of M.Annotate
;; below. With a visual range the thread anchors to those lines; with
;; none it becomes a whole-file comment on the current buffer
(fn annotate-flow [opts]
  (with-pan (let [context (get-visual-lines opts)
                  ;; rel-path falls back to the raw buffer name (empty
                  ;; for scratch buffers, absolute outside a repo) —
                  ;; neither shape belongs in a thread, so a file
                  ;; comment requires a name rel-path actually relativized
                  file-path (when (not context) (git.rel-path))
                  repo-file? (and file-path (not= file-path "")
                                     (not= file-path
                                          (vim.api.nvim_buf_get_name 0)))]
              (if (and (not context) (not repo-file?))
                  (schedule-notify "codeboomer: annotate needs a selection or a repo file"
                                   vim.log.levels.ERROR)
                  (input.open {:title " Annotate> "
                               :on-submit (fn [lines]
                                            (let [text (concat-list lines)]
                                              ;; the DB is the only store now — an
                                              ;; empty note would only pollute threads
                                              (if (= text "")
                                                  (schedule-notify "codeboomer: empty annotation ignored"
                                                                   vim.log.levels.WARN)
                                                  (ensure-session (fn []
                                                                    (if context
                                                                        (review.user-comment (review.current-session-id)
                                                                                             context.file
                                                                                             context.line1
                                                                                             context.line2
                                                                                             context.lines
                                                                                             text)
                                                                        (review.file-comment (review.current-session-id)
                                                                                             file-path
                                                                                             text))
                                                                    ;; let an open review pane pick the
                                                                    ;; fresh thread up
                                                                    (vim.api.nvim_exec_autocmds :User
                                                                                                {:pattern :CodeboomerAnnotated}))))))})))))$

;; a review's OLD side is for reading: its line numbers belong to the
;; other end of the diff and threads would anchor to the base sha —
;; ReviewSide back first
(set M.Annotate (fn [opts]
                  (if (= :old vim.b.codeboomer_review_side)
                      (schedule-notify "codeboomer: annotations anchor to the new code — :Codeboomer ReviewSide back first"
                                       vim.log.levels.WARN)
                      (annotate-flow opts))))

;; ship every unsent user message of the chosen session to the pane,
;; wrapped in the directive, then mark them sent. One message per
;; LOGICAL THREAD: the message already carries the whole conversation
;; (both halves of the pair), so several unsent comments of one
;; thread (a back-and-forth) would otherwise ship N near-identical
;; copies
(fn flush-pending [directive-text]
  (let [pending (review.pending-for-flush (review.current-session-id))]
    (if (= 0 (length pending))
        (schedule-notify "codeboomer: nothing to flush — no unsent messages"
                         vim.log.levels.WARN)
        (let [seen {}
              threads []]
          (each [_ a (ipairs pending)]
            (when (not (. seen (or a.thread.id 0)))
              (tset seen (or a.thread.id 0) true)
              (table.insert threads a.thread)))
          (let [messages (icollect [_ t (ipairs threads)]
                           (thread-message t))
                annotations (concat-list-with-format messages
                                                     "==Section Start==" "===="
                                                     "==Section End==")]
            (send-keys-to-selected-pane (.. annotations
                                            (agent.reply-instructions)
                                            directive-text "\n"))
            (review.mark-annotations :sent
                                     (icollect [_ a (ipairs pending)]
                                       a.comment.id)))))))

(set M.FlushWithDirective
     (fn []
       (with-pan (let [fzf (require :fzf-lua)
                       all-directives (directives.list)
                       lines (icollect [_ d (ipairs all-directives)]
                               d.label)]
                   (fzf.fzf_exec lines
                                 {:prompt "Pick a Directive> "
                                  :actions {:default (fn [selected]
                                                       (let [directive-text (directives.get (. selected
                                                                                               1))]
                                                         (ensure-session #(flush-pending directive-text))))}})))))

M
