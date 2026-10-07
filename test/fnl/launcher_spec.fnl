(local helpers (require :cb_helpers))

(local {: api : clear : eq : fixtures} helpers)
(local files fixtures.files)

(local codeboomer (helpers.module :codeboomer))
(local review (helpers.module :codeboomer.review))

(helpers.env)

(local agent-prompt "Review agent> ")
(local scope-prompt "Review what> ")
(local commit-prompt "Review from commit (inclusive)> ")

(fn logged? [text]
  (not= nil (: (helpers.fake-log :tmux.log) :find text 1 true)))

(fn notified? [text]
  (accumulate [found false _ n (ipairs (helpers.notifications)) &until found]
    (not= nil (n.msg:find text 1 true))))

(fn settle []
  (helpers.exec_lua #(vim.wait 50)))

(fn launch []
  (api.nvim_command "Codeboomer LaunchReviewer")
  (settle))

(fn commit [message]
  (helpers.git :commit :-q :--allow-empty :-m message)
  (vim.trim (helpers.git :rev-parse :HEAD)))

(describe :LaunchReviewer
          (fn []
            (before_each (fn []
                           (clear)
                           (helpers.setup-test-repo)
                           (helpers.setup-codeboomer)
                           (api.nvim_command "runtime plugin/codeboomer.lua")
                           (codeboomer.setup {:prompting {:review_agents [{:label :claude
                                                                           :argv [:agent
                                                                                  :--flag]}
                                                                          {:label :pi
                                                                           :argv [:pi-agent]}]}})
                           (helpers.edit files.main)
                           (helpers.fzf-pick scope-prompt :Commits)))
            (it "asks for the agent, then for what to review"
                (fn []
                  (launch)
                  (eq [agent-prompt scope-prompt commit-prompt]
                      (helpers.fzf-prompts))))
            (it "skips the agent picker when only one is configured"
                (fn []
                  (helpers.restart)
                  (api.nvim_command "runtime plugin/codeboomer.lua")
                  (codeboomer.setup {:prompting {:review_agents [{:label :claude
                                                                  :argv [:agent]}]}})
                  (helpers.edit files.main)
                  (helpers.fzf-pick scope-prompt :Commits)
                  (launch)
                  (eq [scope-prompt commit-prompt] (helpers.fzf-prompts))
                  (assert.is_true (logged? "-- agent Review"))))
            (it "runs the picked agent in a new window on the work tree, prompt last"
                (fn []
                  (helpers.fzf-pick agent-prompt :pi)
                  (launch)
                  (assert.is_true (logged? (.. "new-window -d -P -F #{pane_id} -c "
                                               helpers.repo
                                               " -n review:main -- pi-agent Review")))))
            (it "points the agent at the shim's help"
                (fn []
                  (launch)
                  (assert.is_true (logged? "/codeboomer-agent — run it with `help` first."))))
            (describe "reviewing commits"
                      (fn []
                        (it "reviews from the picked commit through HEAD"
                            (fn []
                              (let [sha (commit :widget)]
                                (commit :gadget)
                                (helpers.fzf-pick commit-prompt :widget)
                                (launch)
                                (assert.is_true (logged? (.. "(inclusive) through HEAD (`git log -p --first-parent "
                                                             sha "~1..HEAD`)"))))))
                        (it "diffs the root commit against the empty tree"
                            (fn []
                              (commit :widget)
                              (helpers.fzf-pick commit-prompt :init)
                              (launch)
                              (assert.is_true (logged? "from the root commit"))
                              (assert.is_true (logged? "git diff 4b825dc642cb6eb9a060e54bf8d69288fbee4904 HEAD"))))))
            (describe "reviewing uncommitted changes"
                      (fn []
                        (before_each #(helpers.fzf-pick scope-prompt
                                                        :Uncommitted))
                        (it "names the working tree changes"
                            (fn []
                              (helpers.write-to-file files.main [:changed])
                              (launch)
                              (assert.is_true (logged? "Review the uncommitted changes on branch main"))))
                        (it "refuses a clean tree"
                            (fn []
                              (launch)
                              (assert.is_true (notified? "nothing uncommitted"))
                              (assert.is_false (logged? :new-window))))))
            (describe "reviewing a PR"
                      (fn []
                        (before_each (fn []
                                       (helpers.fake-gh-json :pr-list.json
                                                             [fixtures.pr])
                                       (helpers.fake-gh-text (.. :pr-diff-
                                                                 fixtures.pr.number
                                                                 :.txt)
                                                             fixtures.pr-diff)
                                       (helpers.fake-gh-jsonl (.. :pulls-
                                                                  fixtures.pr.number
                                                                  :-comments.jsonl)
                                                              [])
                                       (helpers.fzf-pick scope-prompt
                                                         "GitHub PR")))
                        (it "opens the review through Review's own picker, then launches"
                            (fn []
                              (launch)
                              (helpers.expectf #(assert (logged? "Review pull request #42 (`gh pr diff 42`)")))
                              (eq fixtures.pr.number
                                  (. (review.session-for) :pr_number))
                              (assert.is_true (vim.list_contains (helpers.fzf-prompts)
                                                                 "Pick a PR> "))))))
            (describe "with gitsigns installed"
                      (fn []
                        (before_each #(helpers.exec_lua (fn []
                                                          (set _G.gitsigns_bases
                                                               [])
                                                          (tset package.preload
                                                                :gitsigns
                                                                (fn []
                                                                  {:change_base (fn [base
                                                                                     global?
                                                                                     cb]
                                                                                  (table.insert _G.gitsigns_bases
                                                                                                {: base
                                                                                                 :global global?})
                                                                                  (cb))})))))

                        (fn bases []
                          (helpers.exec_lua "return _G.gitsigns_bases"))

                        (fn quickfix []
                          (helpers.exec_lua (fn []
                                              (let [qf (vim.fn.getqflist {:title 1
                                                                          :items 1})]
                                                {:title qf.title
                                                 :files (icollect [_ i (ipairs qf.items)]
                                                          (vim.fn.fnamemodify (vim.fn.bufname i.bufnr)
                                                                              ":t"))}))))

                        (it "moves the base to the picked commit's parent and lists what changed since"
                            (fn []
                              (let [sha (commit :widget)]
                                (helpers.write-to-file files.main [:changed])
                                (helpers.fzf-pick commit-prompt :widget)
                                (launch)
                                (eq [{:base (.. sha "^") :global true}] (bases))
                                (eq {:title (.. "Changes since " sha "^")
                                     :files [files.main]}
                                    (quickfix)))))
                        (it "diffs uncommitted work against HEAD, untracked files included"
                            (fn []
                              (helpers.write-to-file files.main [:changed])
                              (helpers.write-to-file :new.txt [:fresh])
                              (helpers.fzf-pick scope-prompt :Uncommitted)
                              (launch)
                              (eq [{:base :HEAD :global true}] (bases))
                              (eq [files.main :new.txt] (. (quickfix) :files))))
                        (it "leaves gitsigns alone when the tmux launch fails"
                            (fn []
                              (helpers.exec_lua (fn [path]
                                                  (vim.fn.writefile ["no server running"]
                                                                    path))
                                                (.. helpers.fakes
                                                    :/tmux-new-window-error))
                              (launch)
                              (eq [] (bases))))))
            (it "tethers the new window as the pane"
                (fn []
                  (launch)
                  (api.nvim_command "1,2Codeboomer SendSelection")
                  (assert.is_true (logged? "paste-buffer -p -r -d -b codeboomer-paste -t %9"))
                  (assert.is_false (vim.list_contains (helpers.fzf-prompts)
                                                      "Pick a Pane> "))))
            (it "reports a tmux failure and tethers nothing"
                (fn []
                  (helpers.exec_lua (fn [path]
                                      (vim.fn.writefile ["no server running"]
                                                        path))
                                    (.. helpers.fakes :/tmux-new-window-error))
                  (launch)
                  (assert.is_true (notified? "LaunchReviewer failed: no server running"))
                  (api.nvim_command "1,2Codeboomer SendSelection")
                  (assert.is_true (vim.list_contains (helpers.fzf-prompts)
                                                     "Pick a Pane> "))))
            (it "refuses a detached HEAD"
                (fn []
                  (helpers.git :checkout :-q :--detach)
                  (launch)
                  (assert.is_true (notified? "needs a checked-out branch"))
                  (eq [] (helpers.fzf-prompts))))))
