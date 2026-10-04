(local helpers (require :cb_helpers))

(local {: api : clear : eq : matches : fixtures : expectf : rest : find-pane}
       helpers)

(local exec-lua helpers.exec_lua)
(local files fixtures.files)

(local review (helpers.module :codeboomer.review))
(local github (helpers.module :codeboomer.github))
(local sidebar (helpers.module :codeboomer.sidebar))
(local review-mode (helpers.module :codeboomer.review-mode))
(local codeboomer (helpers.module :codeboomer))

(local error-level 4)
(local info-level 2)

(helpers.env)

(fn sql [statement]
  (exec-lua (fn [statement]
              (let [db ((. (require :codeboomer.singleton) :get-db))
                    res (db:with_open #($1:eval statement))]
                (if (= :table (type res)) res []))) statement))

(fn live-sessions []
  (sql "select * from session where deleted_at is null"))

(fn fake-pr [pr comments]
  (helpers.fake-gh-json (.. :pr-view- pr.number :.json) pr)
  (helpers.fake-gh-text (.. :pr-diff- pr.number :.txt) fixtures.pr-diff)
  (helpers.fake-gh-jsonl (.. :pulls- pr.number :-comments.jsonl) comments))

(fn notified [level]
  (icollect [_ n (ipairs (helpers.notifications))]
    (when (= n.level level) n.msg)))

(fn wait-notified [level pattern]
  (expectf #(assert (accumulate [hit false _ msg (ipairs (notified level))
                                 &until hit]
                      (not= nil (msg:find pattern)))
                    (.. "no notification matching " pattern ", got: "
                        (vim.inspect (helpers.notifications))))))

(fn clear-notifications []
  (exec-lua #(set _G.notifications [])))

(fn bound-pr []
  (?. (review.session-for) :pr_number))

(fn review-pr [pr-number]
  (clear-notifications)
  (review-mode.open pr-number))

(fn thread-on-line [sid line]
  (accumulate [found nil _ t (ipairs (review.threads-for-session sid))
               &until found]
    (when (= t.line_start line) t)))

(describe :sessions
          (fn []
            (before_each (fn []
                           (clear)
                           (helpers.setup-test-repo)
                           (helpers.setup-codeboomer)
                           (helpers.edit files.main)))
            (describe "resetting a reviewed branch"
                      (fn []
                        (var sid nil)
                        (before_each (fn []
                                       (set sid (review.ensure-session))
                                       (review.set-session-pr sid 42)
                                       (github.import-items sid
                                                            [fixtures.pulled-item])))
                        (it "re-imports the PR's comments into the branch's next session"
                            (fn []
                              (review.delete-session sid)
                              (let [next-sid (review.ensure-session)]
                                (eq 1
                                    (github.import-items next-sid
                                                         [fixtures.pulled-item]))
                                (eq 1
                                    (length (review.review-rows-for-session next-sid))))))
                        (it "joins later replies to the next session's thread"
                            (fn []
                              (review.delete-session sid)
                              (let [next-sid (review.ensure-session)]
                                (github.import-items next-sid
                                                     [fixtures.pulled-item])
                                (github.import-items next-sid
                                                     [fixtures.pr-reply])
                                (eq 2
                                    (length (review.comments-for (. (thread-on-line next-sid
                                                                                    fixtures.pulled-item.line)
                                                                    :id)))))))
                        (it "keeps a resolved pulled thread resolved on re-pull"
                            (fn []
                              (review.resolve-thread (. (thread-on-line sid
                                                                        fixtures.pulled-item.line)
                                                        :id))
                              (eq 0
                                  (github.import-items sid
                                                       [fixtures.pulled-item]))))))
            (describe "one live session per branch"
                      (fn []
                        (fn insert-duplicate [sid]
                          (sql (: "insert into session (branch, repo_id)
                   select branch, repo_id from session where id = %d"
                                  :format sid)))

                        (it "keeps session creation behind ensure-session"
                            (fn []
                              (eq :nil
                                  (exec-lua "return type(require('codeboomer.review')['create-session'])"))))
                        (it "is enforced by the database"
                            (fn []
                              (let [sid (review.ensure-session)]
                                (eq false (pcall insert-duplicate sid)))))
                        (it "allows a new session once the old one is reset"
                            (fn []
                              (let [sid (review.ensure-session)]
                                (review.delete-session sid)
                                (helpers.neq sid (review.ensure-session))
                                (eq 1 (length (live-sessions))))))))
            (describe :Review
                      (fn []
                        (before_each (fn []
                                       (fake-pr fixtures.pr
                                                [fixtures.pulled-item])))
                        (it "binds the branch session to a PR whose head is the checked-out branch"
                            (fn []
                              (review-pr fixtures.pr.number)
                              (wait-notified info-level "pulled 1 new comment")
                              (eq fixtures.pr.number (bound-pr))
                              (matches "pr view 42 %-%-json [%w,]*headRefName"
                                       (helpers.fake-log :gh.log))))
                        (it "refuses a PR whose head is another branch"
                            (fn []
                              (fake-pr fixtures.other-branch-pr [])
                              (review-pr fixtures.other-branch-pr.number)
                              (wait-notified error-level :feature)
                              (eq [] (live-sessions))))
                        (it "refuses a PR picked from the list whose head is another branch"
                            (fn []
                              (fake-pr fixtures.other-branch-pr [])
                              (helpers.fake-gh-json :pr-list.json
                                                    [fixtures.other-branch-pr])
                              (review-pr nil)
                              (wait-notified error-level :feature)
                              (eq [] (live-sessions))))
                        (describe "on a local branch named apart from the PR's head"
                                  (fn []
                                    (before_each (fn []
                                                   (fake-pr fixtures.other-branch-pr
                                                            [])
                                                   (helpers.git :checkout :-q
                                                                :-b :pr-44)
                                                   (api.nvim_command :edit!)))
                                    (it "binds when the branch tracks the PR's head"
                                        (fn []
                                          (helpers.git :config
                                                       :branch.pr-44.merge
                                                       :refs/heads/feature)
                                          (review-pr fixtures.other-branch-pr.number)
                                          (expectf #(eq fixtures.other-branch-pr.number
                                                        (bound-pr)))))
                                    (it "binds when the branch tracks the PR's pull ref"
                                        (fn []
                                          (helpers.git :config
                                                       :branch.pr-44.merge
                                                       :refs/pull/44/head)
                                          (review-pr fixtures.other-branch-pr.number)
                                          (expectf #(eq fixtures.other-branch-pr.number
                                                        (bound-pr)))))
                                    (it "binds when the branch sits on the PR's head commit"
                                        (fn []
                                          (fake-pr (vim.tbl_extend :force
                                                                   fixtures.other-branch-pr
                                                                   {:headRefOid (vim.trim (helpers.git :rev-parse
                                                                                                       :HEAD))})
                                                   [])
                                          (review-pr fixtures.other-branch-pr.number)
                                          (expectf #(eq fixtures.other-branch-pr.number
                                                        (bound-pr)))))
                                    (it "refuses when the branch neither tracks nor sits on the PR's head"
                                        (fn []
                                          (review-pr fixtures.other-branch-pr.number)
                                          (wait-notified error-level
                                                         "neither tracks it")
                                          (eq [] (live-sessions))))))
                        (it "refuses to re-bind the session to another PR of the same branch"
                            (fn []
                              (review-pr fixtures.pr.number)
                              (wait-notified info-level "pulled 1 new comment")
                              (fake-pr fixtures.same-branch-pr [])
                              (review-pr fixtures.same-branch-pr.number)
                              (wait-notified error-level :ResetSession)
                              (eq fixtures.pr.number (bound-pr))))
                        (it "reopens the same PR in the same session"
                            (fn []
                              (review-pr fixtures.pr.number)
                              (wait-notified info-level "pulled 1 new comment")
                              (let [sid (. (review.session-for) :id)]
                                (review-pr fixtures.pr.number)
                                (wait-notified info-level
                                               "pulled 0 new comment")
                                (eq sid (. (review.session-for) :id))
                                (eq 1
                                    (length (review.review-rows-for-session sid))))))))
            (describe "a detached HEAD"
                      (fn []
                        (before_each (fn []
                                       (fake-pr fixtures.pr [])
                                       (helpers.git :checkout :-q :--detach)
                                       (api.nvim_command :edit!)))
                        (it "gets no session"
                            (fn []
                              (assert.is_nil (review.ensure-session))
                              (eq [] (live-sessions))))
                        (it "refuses Review"
                            (fn []
                              (review-pr fixtures.pr.number)
                              (wait-notified error-level "detached HEAD")
                              (eq [] (live-sessions))))))
            (describe "after a restart"
                      (fn []
                        (var code-win nil)
                        (var tab nil)

                        (fn promote-at [line]
                          (rest code-win line)
                          (exec-lua (fn [win]
                                      (vim.api.nvim_set_current_win win)
                                      (vim.api.nvim_win_set_cursor win [1 0])
                                      ((. (vim.fn.maparg :p :n false true)
                                          :callback)))
                                    (find-pane tab)))

                        (before_each (fn []
                                       (fake-pr fixtures.pr [])
                                       (review-pr fixtures.pr.number)
                                       (wait-notified info-level
                                                      "pulled 0 new comment")
                                       (let [sid (. (review.session-for) :id)]
                                         (review.user-comment sid files.main 40
                                                              40
                                                              (helpers.content-snapshot 40
                                                                                        40)
                                                              "on the diff")
                                         (review.user-comment sid files.main 80
                                                              80
                                                              (helpers.content-snapshot 80
                                                                                        80)
                                                              "off the diff"))
                                       (helpers.restart)
                                       (helpers.edit files.main)
                                       (set code-win (api.nvim_get_current_win))
                                       (set tab (api.nvim_get_current_tabpage))
                                       (sidebar.reload-threads)))
                        (it "promotes on the PR-bound session before any review command runs"
                            (fn []
                              (promote-at 40)
                              (let [sid (. (review.session-for) :id)]
                                (assert.is_not_nil (review.twin (. (thread-on-line sid
                                                                                   40)
                                                                   :id))))))
                        (it "refuses threads outside the PR diff"
                            (fn []
                              (promote-at 80)
                              (wait-notified error-level "outside the PR diff")
                              (let [sid (. (review.session-for) :id)]
                                (assert.is_nil (review.twin (. (thread-on-line sid
                                                                               80)
                                                               :id))))))))
            (describe "the session schema"
                      (fn []
                        (it "has no unused commit columns"
                            (fn []
                              (review.ensure-session)
                              (let [columns (icollect [_ c (ipairs (sql "pragma table_info(session)"))]
                                              c.name)]
                                (assert.is_false (vim.list_contains columns
                                                                    :head_commit))
                                (assert.is_false (vim.list_contains columns
                                                                    :base_commit)))))))
            (describe :flushing
                      (fn []
                        (var sid nil)
                        (before_each (fn []
                                       (codeboomer.setup {})
                                       (set sid (review.ensure-session))
                                       (review.user-comment sid files.main 40
                                                            40 :code "flush me")
                                       (sidebar.reload-threads)
                                       (codeboomer.SetPane)
                                       (api.nvim_command (.. "cd "
                                                             helpers.scratch))))

                        (fn wait-flushed []
                          (expectf #(assert (not= nil
                                                  (: (helpers.fake-log :tmux-paste.txt)
                                                     :find "flush me" 1 true))
                                            (.. "nothing was pasted into the tmux pane; notified: "
                                                (vim.inspect (helpers.notifications))))))

                        (it "sends the branch's messages from a code window outside the cwd"
                            (fn []
                              (codeboomer.FlushWithDirective)
                              (wait-flushed)))
                        (it "sends the branch's messages from the comments pane outside the cwd"
                            (fn []
                              (let [code-win (api.nvim_get_current_win)
                                    tab (api.nvim_get_current_tabpage)]
                                (rest code-win 40)
                                (api.nvim_set_current_win (find-pane tab))
                                (codeboomer.FlushWithDirective)
                                (wait-flushed))))
                        (it "counts replies written from the comments pane outside the cwd as the user's"
                            (fn []
                              (let [code-win (api.nvim_get_current_win)
                                    tab (api.nvim_get_current_tabpage)]
                                (rest code-win 40)
                                (api.nvim_set_current_win (find-pane tab))
                                (review.user-reply (. (thread-on-line sid 40)
                                                      :id)
                                                   "from the pane")
                                (eq 2 (length (review.pending-for-flush sid))))))))))
