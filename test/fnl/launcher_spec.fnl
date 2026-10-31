(local helpers (require :cb_helpers))

(local {: api : clear : eq : fixtures} helpers)
(local files fixtures.files)

(local codeboomer (helpers.module :codeboomer))
(local review (helpers.module :codeboomer.review))

(helpers.env)

(local agent-prompt "Review agent> ")
(local scope-prompt "Review what> ")
(local commit-prompt "Review from commit (inclusive)> ")

;; agents run sh stand-ins instead of the real binaries: the stand-in
;; records its cwd and the argv it was started with ($* — the agent's
;; marker plus the review prompt, appended last), and cats its stdin
;; to a log, standing in for the harness reading the channel
(fn agent-entry [label marker]
  {: label
   :argv [:sh
          :-c
          (string.format "pwd > %s/agent-cwd.log; printf '%%s\\n' \"$*\" > %s/agent-argv.log; cat > %s/agent-in.log; sleep 5"
                         helpers.fakes helpers.fakes helpers.fakes)
          :sh
          marker]})

(fn argv-logged? [text]
  (not= nil (: (helpers.fake-log :agent-argv.log) :find text 1 true)))

(fn in-logged? [text]
  (not= nil (: (helpers.fake-log :agent-in.log) :find text 1 true)))

(fn buf-named [label]
  ;; buffer names come back absolute — match the trailing component
  (accumulate [found nil _ b (ipairs (helpers.exec_lua "return vim.api.nvim_list_bufs()"))
               &until found]
    (when (= label (string.match (api.nvim_buf_get_name b) "[^/]+$"))
      b)))

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
                           (codeboomer.setup {:prompting {:review_agents [(agent-entry :claude
                                                                                       :agent)
                                                                          (agent-entry :pi
                                                                                       :pi-agent)]}})
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
                  (codeboomer.setup {:prompting {:review_agents [(agent-entry :claude
                                                                              :agent)]}})
                  (helpers.edit files.main)
                  (helpers.fzf-pick scope-prompt :Commits)
                  (launch)
                  (eq [scope-prompt commit-prompt] (helpers.fzf-prompts))
                  (helpers.expectf #(assert (argv-logged? "agent Review")))))
            (it "runs the picked agent in a terminal buffer on the work tree, prompt last"
                (fn []
                  (helpers.fzf-pick agent-prompt :pi)
                  (launch)
                  (helpers.expectf #(do
                                      (assert (argv-logged? "pi-agent Review"))
                                      (assert (= (vim.trim (helpers.fake-log :agent-cwd.log))
                                                 helpers.repo))
                                      (assert (helpers.exec_lua (fn [b]
                                                                  (vim.api.nvim_buf_get_var b
                                                                                            :terminal_job_id))
                                                                (buf-named "review:main")))
                                      nil))))
            (it "points the agent at the shim's help"
                (fn []
                  (launch)
                  (helpers.expectf #(assert (argv-logged? "/codeboomer-agent — run it with `help` first.")))))
            (describe "reviewing commits"
                      (fn []
                        (it "reviews from the picked commit through HEAD"
                            (fn []
                              (let [sha (commit :widget)]
                                (commit :gadget)
                                (helpers.fzf-pick commit-prompt :widget)
                                (launch)
                                (helpers.expectf #(assert (argv-logged? (.. "(inclusive) through HEAD (`git log -p --first-parent "
                                                                            sha
                                                                            "~1..HEAD`)")))))))
                        (it "diffs the root commit against the empty tree"
                            (fn []
                              (commit :widget)
                              (helpers.fzf-pick commit-prompt :init)
                              (launch)
                              (helpers.expectf #(do
                                                  (assert (argv-logged? "from the root commit"))
                                                  (assert (argv-logged? "git diff 4b825dc642cb6eb9a060e54bf8d69288fbee4904 HEAD"))
                                                  nil))))))
            (describe "reviewing uncommitted changes"
                      (fn []
                        (before_each #(helpers.fzf-pick scope-prompt
                                                        :Uncommitted))
                        (it "names the working tree changes"
                            (fn []
                              (helpers.write-to-file files.main [:changed])
                              (launch)
                              (helpers.expectf #(assert (argv-logged? "Review the uncommitted changes on branch main"))))
                            (it "refuses a clean tree"
                                (fn []
                                  (launch)
                                  (assert.is_true (notified? "nothing uncommitted"))
                                  (assert.is_false (argv-logged? :Review))))))
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
                                        (helpers.expectf #(assert (argv-logged? "Review pull request #42 (`gh pr diff 42`)")))
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
                                          (helpers.write-to-file files.main
                                                                 [:changed])
                                          (helpers.fzf-pick commit-prompt
                                                            :widget)
                                          (launch)
                                          (eq [{:base (.. sha "^")
                                                :global true}]
                                              (bases))
                                          (eq {:title (.. "Changes since " sha
                                                          "^")
                                               :files [files.main]}
                                              (quickfix)))))
                                  (it "diffs uncommitted work against HEAD, untracked files included"
                                      (fn []
                                        (helpers.write-to-file files.main
                                                               [:changed])
                                        (helpers.write-to-file :new.txt
                                                               [:fresh])
                                        (helpers.fzf-pick scope-prompt
                                                          :Uncommitted)
                                        (launch)
                                        (eq [{:base :HEAD :global true}]
                                            (bases))
                                        (eq [files.main :new.txt]
                                            (. (quickfix) :files))))
                                  (it "leaves gitsigns alone when the launch fails"
                                      (fn []
                                        (codeboomer.setup {:prompting {:review_agents [{:label :claude
                                                                                        :argv [:codeboomer-missing-binary]}]}})
                                        (launch)
                                        (helpers.expectf #(assert (notified? "LaunchReviewer failed")))
                                        (eq [] (bases))))
                                  (describe "on a PR"
                                            (fn []
                                              (fn review-pr [pr]
                                                (helpers.fake-gh-json :pr-list.json
                                                                      [pr])
                                                (helpers.fake-gh-text (.. :pr-diff-
                                                                          pr.number
                                                                          :.txt)
                                                                      fixtures.pr-diff)
                                                (helpers.fake-gh-jsonl (.. :pulls-
                                                                           pr.number
                                                                           :-comments.jsonl)
                                                                       [])
                                                (helpers.fzf-pick scope-prompt
                                                                  "GitHub PR")
                                                (launch))

                                              (fn commit-change [message]
                                                (helpers.write-to-file files.main
                                                                       [message])
                                                (helpers.git :commit :-q :-am
                                                             message)
                                                (vim.trim (helpers.git :rev-parse
                                                                       :HEAD)))

                                              (local pr-on-trunk
                                                     (vim.tbl_extend :force
                                                                     fixtures.pr
                                                                     {:baseRefName :trunk}))
                                              (it "moves the base to where the branch left the PR's base"
                                                  (fn []
                                                    (let [fork (vim.trim (helpers.git :rev-parse
                                                                                      :HEAD))]
                                                      (helpers.git :branch
                                                                   :trunk)
                                                      (commit-change :widget)
                                                      (review-pr pr-on-trunk)
                                                      (helpers.expectf #(do
                                                                          (eq [{:base fork
                                                                                :global true}]
                                                                              (bases))
                                                                          nil))
                                                      (eq [files.main]
                                                          (. (quickfix) :files)))))
                                              (it "prefers the remote base over a stale local one"
                                                  (fn []
                                                    (helpers.git :branch :trunk)
                                                    (let [fetched (commit-change :widget)]
                                                      (helpers.git :update-ref
                                                                   :refs/remotes/origin/trunk
                                                                   fetched)
                                                      (commit-change :gadget)
                                                      (review-pr pr-on-trunk)
                                                      (helpers.expectf #(do
                                                                          (eq [{:base fetched
                                                                                :global true}]
                                                                              (bases))
                                                                          nil)))))
                                              (it "warns and leaves gitsigns alone when the base can't be resolved"
                                                  (fn []
                                                    (review-pr fixtures.pr)
                                                    (helpers.expectf #(assert (notified? "no diff base")))
                                                    (eq [] (bases))))))))
                      (it "tethers the terminal buffer as the pane"
                          (fn []
                            (launch)
                            (api.nvim_command "1,2Codeboomer SendSelection")
                            (helpers.expectf #(assert (in-logged? "line 1")))
                            (assert.is_false (vim.list_contains (helpers.fzf-prompts)
                                                                "Pick a Pane> "))))
                      (it "reports a failed launch and tethers nothing"
                          (fn []
                            ;; overriding the built-in claude label keeps it a
                            ;; single agent — no picker between setup and failure
                            (codeboomer.setup {:prompting {:review_agents [{:label :claude
                                                                            :argv [:codeboomer-missing-binary]}]}})
                            (launch)
                            (helpers.expectf #(assert (notified? "LaunchReviewer failed")))
                            (api.nvim_command "1,2Codeboomer SendSelection")
                            (assert.is_true (vim.list_contains (helpers.fzf-prompts)
                                                               "Pick a Pane> "))))
                      (it "refuses a detached HEAD"
                          (fn []
                            (helpers.git :checkout :-q :--detach)
                            (launch)
                            (assert.is_true (notified? "needs a checked-out branch"))
                            (eq [] (helpers.fzf-prompts)))))))
