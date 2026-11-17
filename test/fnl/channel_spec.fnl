(local helpers (require :cb_helpers))

(local {: api : clear : eq : fixtures} helpers)
(local files fixtures.files)

(local channel (helpers.module :codeboomer.channel))
(local codeboomer (helpers.module :codeboomer))

(helpers.env)

;; a stand-in for the harness on the other side of the channel: records
;; where it was started and streams what the pty delivers into a log
(fn stand-in-argv [label]
  [:sh
   :-c
   (string.format "pwd > %s/%s-cwd.log; cat > %s/%s-in.log; sleep 5"
                  helpers.fakes label helpers.fakes label)])

(fn find-pane [panes pane-id]
  (accumulate [found nil _ p (ipairs panes) &until found]
    (when (= pane-id p.pane-id) p)))

(fn notified? [text]
  (accumulate [found false _ n (ipairs (helpers.notifications)) &until found]
    (not= nil (n.msg:find text 1 true))))

;; how many windows of the current tabpage show a buffer named {label}
(fn wins-showing [label]
  (helpers.exec_lua (fn [n]
                      (accumulate [cnt 0 _ w (ipairs (vim.api.nvim_tabpage_list_wins 0))]
                        (if (= n
                               (string.match (vim.api.nvim_buf_get_name (vim.api.nvim_win_get_buf w))
                                             "[^/]+$"))
                            (+ 1 cnt)
                            cnt))) label))

(describe "the channel driver"
          (fn []
            (before_each (fn []
                           (clear)
                           (helpers.setup-test-repo)
                           (helpers.setup-codeboomer)
                           (api.nvim_command "runtime plugin/codeboomer.lua")
                           (helpers.edit files.main)))
            (it "spawns a named terminal buffer on the work tree, focus intact"
                (fn []
                  (let [pane (channel.spawn helpers.repo :chan-test
                                            (stand-in-argv :chan))]
                    (eq :channel pane.driver)
                    (eq :nvim pane.session-name)
                    (eq :sh pane.pane-current-command)
                    (eq helpers.repo pane.pane-current-path)
                    (eq (.. :n pane.buf) pane.pane-id)
                    (eq :chan-test
                        (string.match (api.nvim_buf_get_name pane.buf) "[^/]+$"))
                    (assert (api.nvim_buf_get_var pane.buf :terminal_job_id))
                    ;; the split never stole the cursor
                    (eq files.main
                        (string.match (api.nvim_buf_get_name 0) "[^/]+$"))
                    (helpers.expectf #(let [cwd (vim.trim (helpers.fake-log :chan-cwd.log))]
                                        (assert (= cwd helpers.repo)))))))
            (it "sends through the pty wrapped in bracketed paste, Enter last"
                (fn []
                  (let [pane (channel.spawn helpers.repo :paste-proc
                                            (stand-in-argv :paste))]
                    (channel.send pane "hello\nworld")
                    (helpers.expectf #(let [in-log (helpers.fake-log :paste-in.log)]
                                        (assert (in-log:find "\027%[200~hello
world\027%[201~" 1
                                                             false))))
                    ;; the trailing Enter reached the child as a newline
                    (helpers.expectf #(let [in-log (helpers.fake-log :paste-in.log)]
                                        (assert (in-log:find "\027%[201~\n" 1
                                                             false))))
                    ;; a dead pane says so instead of erroring
                    (let [(_ err) (channel.send {:pane-id :n99999} :x)]
                      (assert (err:find :gone 1 true))))))
            (it "lists terminal buffers as panes with their last line"
                (fn []
                  (let [pane (channel.spawn helpers.repo :list-proc
                                            (stand-in-argv :list))]
                    (channel.send pane "one\ntwo")
                    (helpers.expectf #(let [p (find-pane (channel.list-panes)
                                                         pane.pane-id)
                                            last-lines (channel.last-lines)]
                                        (assert p)
                                        (eq :channel p.driver)
                                        (eq :sh p.pane-current-command)
                                        (assert (not= ""
                                                      (or (. last-lines
                                                             pane.pane-id)
                                                          ""))))))))
            (it "previews the tail of the buffer and reports gone terminals"
                (fn []
                  (let [pane (channel.spawn helpers.repo :prev-proc
                                            (stand-in-argv :prev))]
                    (channel.send pane "a visible marker")
                    (helpers.expectf #(let [prev (channel.preview pane.pane-id)]
                                        (assert (prev:find "a visible marker" 1
                                                           true))))
                    (eq "(terminal buffer gone)" (channel.preview :n99999)))))
            (it "merges into the pane picker and carries the hybrid preview"
                (fn []
                  (let [pane (channel.spawn helpers.repo :merged-proc
                                            (stand-in-argv :merged))]
                    (helpers.fzf-pick "Pick a Pane> " pane.pane-id)
                    (codeboomer.SetPane)
                    (let [call (. (helpers.fzf-calls) 1)]
                      ;; the fake tmux panes (%1, %2) sit next to ours
                      (assert (accumulate [hit false _ l (ipairs call.lines)
                                           &until hit]
                                (l:find "%1" 1 true)))
                      (assert (accumulate [hit false _ l (ipairs call.lines)
                                           &until hit]
                                (l:find pane.pane-id 1 true)))
                      ;; n-ids route through the parent socket, tmux ids
                      ;; through capture-pane — one command for both
                      (assert (call.preview:find :codeboomer.channel 1 true))
                      (assert (call.preview:find :capture-pane 1 true)))
                    ;; the pick tethered our pane: a raw send lands in the
                    ;; pty without opening the picker again
                    (api.nvim_command "1,2Codeboomer SendSelection")
                    (helpers.expectf #(let [in-log (helpers.fake-log :merged-in.log)]
                                        (assert (in-log:find "line 1" 1 true))))
                    (let [picks (accumulate [n 0 _ p (ipairs (helpers.fzf-prompts))]
                                  (if (= p "Pick a Pane> ") (+ 1 n) n))]
                      (eq 1 picks)))))
            (it "toggles the terminal out of the layout and back, job alive throughout"
                (fn []
                  (let [pane (channel.spawn helpers.repo :tog-proc
                                            (stand-in-argv :tog))]
                    (channel.send pane :first)
                    (helpers.expectf #(let [in-log (helpers.fake-log :tog-in.log)]
                                        (assert (in-log:find :first 1 true))))
                    ;; collapse: no window shows it, the pane still sends —
                    ;; the job was never touched, only hidden
                    (eq :hidden (channel.toggle pane))
                    (eq 0 (wins-showing :tog-proc))
                    (channel.send pane :second)
                    (helpers.expectf #(let [in-log (helpers.fake-log :tog-in.log)]
                                        (assert (in-log:find :second 1 true))))
                    ;; bring it back: the split is there again and the
                    ;; cursor sits in the terminal
                    (eq :shown (channel.toggle pane))
                    (eq 1 (wins-showing :tog-proc))
                    (eq :tog-proc
                        (string.match (api.nvim_buf_get_name (api.nvim_win_get_buf 0))
                                      "[^/]+$"))
                    ;; a dead pane says so instead of erroring
                    (let [(_ err) (channel.toggle {:pane-id :n99999})]
                      (assert (err:find :gone 1 true))))))
            (it "toggles through the command and guards its edges"
                (fn []
                  ;; no pane selected yet — nothing to toggle
                  (codeboomer.TogglePane)
                  (helpers.expectf #(assert (notified? "no pane selected")))
                  ;; a tmux pane owns its window in tmux, not here
                  (helpers.fzf-pick "Pick a Pane> " "%1")
                  (codeboomer.SetPane)
                  (api.nvim_command "Codeboomer TogglePane")
                  (helpers.expectf #(assert (notified? "tmux pane")))))
            (it "wires the agent-posted event into the comments pane"
                (fn []
                  ;; loading the plugin's entry module pulls in the
                  ;; comments pane, whose User autocmds include the
                  ;; evented agent refresh
                  (helpers.exec_lua #(do
                                       (require :codeboomer)
                                       nil))
                  (let [n (helpers.exec_lua (fn []
                                              (length (vim.api.nvim_get_autocmds {:event :User
                                                                                  :pattern :CodeboomerAgentPosted}))))]
                    (assert (> n 0)))))))
