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

(fn all-sessions []
  (sql "select * from session"))

(fn at-head [pr]
  (vim.tbl_extend :force pr
                  {:headRefOid (vim.trim (helpers.git :rev-parse :HEAD))}))

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
            (describe "posting to GitHub"
                      (fn []
                        (it "drafts a file comment into the pending review through GraphQL"
                            (fn []
                              (let [sid (review.ensure-session)]
                                (review.set-session-pr sid 42)
                                (review.user-comment sid files.main 40 40
                                                     (helpers.content-snapshot 40
                                                                               40)
                                                     "on a line")
                                (review.file-comment sid files.readme
                                                     "on the whole file")
                                (each [_ t (ipairs (review.threads-for-session sid))]
                                  (review.promote t.id
                                                  (. (review.comments-for t.id)
                                                     1 :body)
                                                  sid nil))
                                (github.post-threads {:session-id sid})
                                (expectf #(eq 0
                                              (length (review.pending-for-post sid))))
                                (let [[drafted added] (helpers.gh-payloads)]
                                  (eq [files.main]
                                      (icollect [_ c (ipairs drafted.comments)]
                                        c.path))
                                  (eq {:review :PRR_1
                                       :path files.readme
                                       :body "on the whole file"}
                                      added.variables)))))
                        (it "surfaces GitHub's reason when gh rejects the post"
                            (fn []
                              (let [sid (review.ensure-session)]
                                (review.set-session-pr sid 42)
                                (github.import-items sid [fixtures.pulled-item])
                                (review.user-reply (. (thread-on-line sid
                                                                      fixtures.pulled-item.line)
                                                      :id)
                                                   "my reply")
                                (helpers.fake-gh-json :post-error.json
                                                      {:message "Unprocessable Entity"
                                                       :errors ["user_id can only have one pending review per pull request"]
                                                       :status :422})
                                (github.post-threads {:session-id sid})
                                (wait-notified error-level
                                               "one pending review per pull request"))))))
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
                                (eq 1 (length (all-sessions))))))))
            (describe :Review
                      (fn []
                        (before_each (fn []
                                       (fake-pr (at-head fixtures.pr)
                                                [fixtures.pulled-item])))
                        (it "binds the branch session to a PR whose head is the checked-out branch"
                            (fn []
                              (review-pr fixtures.pr.number)
                              (wait-notified info-level "pulled 1 new comment")
                              (eq fixtures.pr.number (bound-pr))
                              (matches "pr view 42 %-%-json [%w,]*headRefName"
                                       (helpers.fake-log :gh.log))))
                        (it "stops the pull at a comment that fails to import, naming it"
                            (fn []
                              (fake-pr (at-head fixtures.pr)
                                       [fixtures.pulled-item
                                        fixtures.pathless-item])
                              (review-pr fixtures.pr.number)
                              (wait-notified error-level
                                             "pull stopped, comment 557 %(%?:41%) failed")
                              (helpers.neq nil
                                           (thread-on-line (review.ensure-session)
                                                           40))))
                        (it "refuses to pull while HEAD is not the PR's head commit"
                            (fn []
                              (fake-pr (vim.tbl_extend :force fixtures.pr
                                                       {:headRefOid "f485d97670cc2e67485b09fe14fb38b16bce8434"})
                                       [fixtures.pulled-item])
                              (review-pr fixtures.pr.number)
                              (wait-notified error-level
                                             "not pulling — HEAD %x+ is not PR #42's head f485d97")
                              (eq [] (review.threads-for-session (review.ensure-session)))
                              (assert.is_nil (string.find (helpers.fake-log :gh.log)
                                                          "/comments" 1 true))))
                        (it "refuses a PR whose head is another branch"
                            (fn []
                              (fake-pr fixtures.other-branch-pr [])
                              (review-pr fixtures.other-branch-pr.number)
                              (wait-notified error-level :feature)
                              (eq [] (all-sessions))))
                        (it "refuses a PR picked from the list whose head is another branch"
                            (fn []
                              (fake-pr fixtures.other-branch-pr [])
                              (helpers.fake-gh-json :pr-list.json
                                                    [fixtures.other-branch-pr])
                              (review-pr nil)
                              (wait-notified error-level :feature)
                              (eq [] (all-sessions))))
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
                                          (fake-pr (at-head fixtures.other-branch-pr)
                                                   [])
                                          (review-pr fixtures.other-branch-pr.number)
                                          (expectf #(eq fixtures.other-branch-pr.number
                                                        (bound-pr)))))
                                    (it "refuses when the branch neither tracks nor sits on the PR's head"
                                        (fn []
                                          (review-pr fixtures.other-branch-pr.number)
                                          (wait-notified error-level
                                                         "neither tracks it")
                                          (eq [] (all-sessions))))))
                        (it "refuses to re-bind the session to another PR of the same branch"
                            (fn []
                              (review-pr fixtures.pr.number)
                              (wait-notified info-level "pulled 1 new comment")
                              (fake-pr (at-head fixtures.same-branch-pr) [])
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
                                       (fake-pr (at-head fixtures.pr) [])
                                       (helpers.git :checkout :-q :--detach)
                                       (api.nvim_command :edit!)))
                        (it "gets no session"
                            (fn []
                              (assert.is_nil (review.ensure-session))
                              (eq [] (all-sessions))))
                        (it "refuses Review"
                            (fn []
                              (review-pr fixtures.pr.number)
                              (wait-notified error-level "detached HEAD")
                              (eq [] (all-sessions))))))
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
                                       (fake-pr (at-head fixtures.pr) [])
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
            (describe "the database file"
                      (fn []
                        (it "is named after the schema version"
                            (fn []
                              (review.ensure-session)
                              (eq (.. helpers.data-home :/nvim/codeboomer-db-v2)
                                  (exec-lua "return require('codeboomer.singleton')['db-path']()"))
                              (eq 1
                                  (helpers.fn.filereadable (.. helpers.data-home
                                                               :/nvim/codeboomer-db-v2)))))
                        (it "leaves an earlier version's file untouched"
                            (fn []
                              (let [legacy (.. helpers.data-home
                                               :/nvim/codeboomer)]
                                (helpers.fn.writefile [:legacy] legacy)
                                (review.ensure-session)
                                (eq [:legacy] (helpers.fn.readfile legacy)))))
                        (it "takes writes again after a batch fails to bind midway"
                            (fn []
                              (review.ensure-session)
                              (eq [false true]
                                  (exec-lua (fn []
                                              (let [singleton (require :codeboomer.singleton)
                                                    sqlite (require :codeboomer.sqlite)
                                                    insert #(: (sqlite.user (singleton.get-db))
                                                               :insert $1)
                                                    unbindable (pcall insert
                                                                      [{:email "before@example.com"}
                                                                       {:email #nil}])]
                                                (singleton.reset-db)
                                                [unbindable
                                                 (pick-values 1
                                                   (pcall insert
                                                          {:email "after@example.com"}))]))))))))
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
