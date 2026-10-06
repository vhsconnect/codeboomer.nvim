(local helpers (require :cb_helpers))

(local {: api : clear : eq : fixtures : expectf} helpers)
(local files fixtures.files)

(local codeboomer (helpers.module :codeboomer))
(local review (helpers.module :codeboomer.review))

(helpers.env)

(fn logged? [name text]
  (not= nil (: (helpers.fake-log name) :find text 1 true)))

(fn float-title []
  (helpers.exec_lua (fn []
                      (accumulate [title nil _ w (ipairs (vim.api.nvim_list_wins))
                                   &until title]
                        (let [c (vim.api.nvim_win_get_config w)]
                          (when (not= c.relative "")
                            (vim.inspect c.title)))))))

(describe "fzf pickers"
          (fn []
            (before_each (fn []
                           (clear)
                           (helpers.setup-test-repo)
                           (helpers.setup-codeboomer)
                           (api.nvim_command "runtime plugin/codeboomer.lua")
                           (codeboomer.setup {:prompting {:one_off_commands [{:label :first
                                                                              :argv [:one]}
                                                                             {:label :second
                                                                              :argv [:two]}]}})
                           (helpers.edit files.main)))
            (describe :SetPane
                      (fn []
                        (it "tethers the picked pane"
                            (fn []
                              (helpers.fzf-pick "Pick a Pane> " "%2")
                              (api.nvim_command "Codeboomer SetPane")
                              (api.nvim_command "1,2Codeboomer SendSelection")
                              (assert.is_true (logged? :tmux.log
                                                       "paste-buffer -p -r -d -b codeboomer-paste -t %2"))))
                        (it "previews the highlighted pane with its id hidden"
                            (fn []
                              (api.nvim_command "Codeboomer SetPane")
                              (let [[call] (helpers.fzf-calls)]
                                (eq "tmux capture-pane -p -t {1} -S -40"
                                    call.preview)
                                (eq {:--with-nth :2..} call.fzf_opts))))))
            (describe :FlushWithDirective
                      (fn []
                        (it "picks the pane, then sends the picked directive's text"
                            (fn []
                              (let [sid (review.ensure-session)]
                                (review.user-comment sid files.main 40 40 :code
                                                     "flush me"))
                              (helpers.fzf-pick "Pick a Directive> "
                                                "Review - execute")
                              (codeboomer.FlushWithDirective)
                              (expectf #(assert (logged? :tmux-paste.txt
                                                         "Make the changes directly")))
                              (eq ["Pick a Pane> " "Pick a Directive> "]
                                  (helpers.fzf-prompts))))))
            (describe :AskOneOff
                      (fn []
                        (it "opens the input for the picked command"
                            (fn []
                              (helpers.fzf-pick "Pick a One-off> " :second)
                              (api.nvim_command "Codeboomer AskOneOff")
                              (expectf #(assert (not= nil
                                                      (: (or (float-title) "")
                                                         :find
                                                         "AskOneOff: second" 1
                                                         true))))))))
            (describe :Review
                      (fn []
                        (it "binds the session to the picked PR"
                            (fn []
                              (let [pr fixtures.same-branch-pr]
                                (helpers.fake-gh-json :pr-list.json
                                                      [fixtures.pr pr])
                                (helpers.fake-gh-text (.. :pr-diff- pr.number
                                                          :.txt)
                                                      fixtures.pr-diff)
                                (helpers.fake-gh-jsonl (.. :pulls- pr.number
                                                           :-comments.jsonl)
                                                       [])
                                (helpers.fzf-pick "Pick a PR> "
                                                  (.. "#" pr.number))
                                (api.nvim_command "Codeboomer Review")
                                (expectf #(eq pr.number
                                              (. (or (review.session-for) {})
                                                 :pr_number))))))))))
