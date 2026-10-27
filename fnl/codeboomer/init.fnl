(global vim vim)

(local config (require :codeboomer.config))
(local input (require :codeboomer.input))
(local directives (require :codeboomer.directives))
(local review (require :codeboomer.review))

;; autocmds 
(local sidebar (require :codeboomer.sidebar))

(local agent (require :codeboomer.agent))
(local one-offs (require :codeboomer.one-offs))
(local git (require :codeboomer.git))
(local tmux (require :codeboomer.tmux))
(local picker (require :codeboomer.picker))
(local reviewer (require :codeboomer.reviewer))

(local state {:pane nil :last-input nil})

(local M {})

(macro with-pan [body]
  `(if state.pane
       ,body
       (choose-pane (tmux.list-panes) (fn [] ,body))))

(fn schedule-notify [msg level]
  (vim.schedule #(vim.notify msg level)))

(set M.setup (fn [opts]
               (config.setup opts)))

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

(fn shorten-path [path]
  (let [home (os.getenv :HOME)]
    (if (and home (= 1 (string.find path home 1 true)))
        (.. "~" (string.sub path (+ 1 (length home))))
        path)))

(fn send-keys-to-selected-pane [text]
  (tmux.send state.pane text))

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

(fn choose-pane [panes ?then]
  (let [last-lines (tmux.last-lines)
        on-pick (fn [pane]
                  (set state.pane pane)
                  (schedule-notify (string.format "codeboomer: pane %s (%s:%s.%s) selected"
                                                  pane.pane-id pane.session-name
                                                  pane.window-index
                                                  pane.pane-index)
                                   vim.log.levels.INFO)
                  (when ?then (?then)))]
    (picker.choose "Pick a Pane> " panes
                   #(pane-display $1 (. last-lines $1.pane-id)) on-pick
                   {:preview tmux.preview-command
                    ;; hide the pane-id from the visible entries — fzf
                    ;; extracts {1} from the original (untransformed) line,
                    ;; so the preview still receives it
                    :fzf_opts {:--with-nth :2..}
                    :winopts {:preview {:wrap false
                                        :layout :vertical
                                        :vertical "down:45%:follow"}}})))

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

(fn choose-one-off [commands k]
  (picker.choose "Pick a One-off> " commands one-off-display k))

;; :Codeboomer ResetSession — terminate this branch's set of comments:
;; delete the branch's session with its threads so the next
;; annotation starts a fresh one; the pane reloads empty via
;; CodeboomerSessionReset. The one replacement for the old session
;; picker's d — with sessions tied to branches there is nothing left
;; to pick
(set M.ResetSession
     (fn []
       (let [sid (sidebar.session-id)]
         (if (not sid)
             (schedule-notify "codeboomer: no session for this branch"
                              vim.log.levels.WARN)
             (do
               (review.delete-session sid)
               (vim.api.nvim_exec_autocmds :User
                                           {:pattern :CodeboomerSessionReset})
               (schedule-notify (string.format "codeboomer: session #%d reset — the next annotation starts a fresh one"
                                               sid)
                                vim.log.levels.INFO))))))

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
        (string.format "regarding %s (thread %s)\n%s" (or t.file_path "?")
                       (or t.id "?") (table.concat conversation "\n\n"))
        (string.format "regarding %s lines %s to %s (thread %s)\n%s\n%s"
                       (or t.file_path "?") (or t.line_start "?")
                       (or t.line_end "?") (or t.id "?") (or t.code_snapshot "")
                       (table.concat conversation "\n\n")))))

(set M.SetPane (fn []
                 (choose-pane (tmux.list-panes))))

;; the picked agent's window becomes the pane — later flushes reach it
(set M.LaunchReviewer
     (fn []
       (reviewer.launch (fn [pane]
                          (set state.pane pane)))))

(set M.SendPrompt
     (fn [opts]
       (with-pan (let [context (get-visual-lines opts)]
                   (input.open {:title " SendPrompt> "
                                :on-submit (fn [lines]
                                             (let [text (concat-list lines)]
                                               (when (not= text "")
                                                 (set state.last-input text)
                                                 (send-keys-to-selected-pane (compose-message context
                                                                                              text)))))})))))

(set M.SendLastPrompt
     (fn [opts]
       (if state.last-input
           (with-pan (let [context (get-visual-lines opts)]
                       (send-keys-to-selected-pane (compose-message context
                                                                    state.last-input))))
           (schedule-notify "codeboomer: no prompt sent yet — nothing to resend"
                            vim.log.levels.WARN))))

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
                                  (not= file-path (vim.api.nvim_buf_get_name 0)))]
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
                                                  ;; the branch's session, find-or-create —
                                                  ;; the one and only per (repo, branch)
                                                  (let [sid (review.ensure-session)]
                                                    (if (not sid)
                                                        (schedule-notify (if (git.repo-root)
                                                                             "codeboomer: annotate needs a checked-out branch — sessions are tied to branches, a detached HEAD has none"
                                                                             "codeboomer: annotate needs a repo file")
                                                                         vim.log.levels.ERROR)
                                                        (do
                                                          (if context
                                                              (review.user-comment sid
                                                                                   context.file
                                                                                   context.line1
                                                                                   context.line2
                                                                                   context.lines
                                                                                   text)
                                                              (review.file-comment sid
                                                                                   file-path
                                                                                   text))
                                                          ;; let an open pane pick the
                                                          ;; fresh thread up
                                                          (vim.api.nvim_exec_autocmds :User
                                                                                      {:pattern :CodeboomerAnnotated})))))))})))))

(set M.Annotate (fn [opts] (annotate-flow opts)))

;; ship every unsent user message of the branch's session to the pane,
;; wrapped in the directive, then mark them sent. One message per
;; LOGICAL THREAD: the message already carries the whole conversation
;; (both halves of the pair), so several unsent comments of one
;; thread (a back-and-forth) would otherwise ship N near-identical
;; copies
(fn flush-pending [directive-text]
  (let [pending (review.pending-for-flush (sidebar.session-id))]
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
                                                     "==Section End==")
                execute? (accumulate [hit false _ a (ipairs pending) &until hit]
                           (= a.comment.body agent.execute-body))]
            (send-keys-to-selected-pane (.. annotations
                                            (agent.reply-instructions)
                                            directive-text "\n"
                                            (if execute?
                                                (agent.execute-instructions)
                                                "")))
            (review.mark-annotations :sent
                                     (icollect [_ a (ipairs pending)]
                                       a.comment.id)))))))

(set M.FlushWithDirective
     (fn []
       (with-pan (picker.choose "Pick a Directive> " (directives.list)
                                #$1.label #(flush-pending $1.text)))))

M
