(local helpers (require :cb_helpers))

(local {: api : clear : eq : fixtures : rest : find-pane} helpers)

(local exec-lua helpers.exec_lua)
(local files fixtures.files)

(local review (helpers.module :codeboomer.review))
(local codeboomer (helpers.module :codeboomer))

(helpers.env)

(fn sql [statement]
  (exec-lua (fn [statement]
              (let [db ((. (require :codeboomer.singleton) :get-db))
                    res (db:with_open #($1:eval statement))]
                (if (= :table (type res)) res []))) statement))

(fn type-and-submit [text]
  (exec-lua (fn [text]
              (let [win (vim.api.nvim_get_current_win)]
                (vim.api.nvim_buf_set_lines (vim.api.nvim_win_get_buf win) 0 -1
                                            false [text])
                (vim.api.nvim_win_close win true))) text))

(fn annotate-lines [path line1 line2 text]
  (helpers.edit path)
  (api.nvim_command (: "normal! %dGV%dG\027" :format line1 line2))
  (api.nvim_command "'<,'>Codeboomer Annotate")
  (type-and-submit text))

(fn annotate-file [path text]
  (helpers.edit path)
  (api.nvim_command "Codeboomer Annotate")
  (type-and-submit text))

(fn press-in-pane [tab key]
  (exec-lua (fn [win key]
              (vim.api.nvim_set_current_win win)
              (vim.api.nvim_win_set_cursor win [1 0])
              ((. (vim.fn.maparg key :n false true) :callback)))
            (find-pane tab) key))

(fn thread-on [sid path]
  (accumulate [found nil _ t (ipairs (review.threads-for-session sid))
               &until found]
    (when (= t.file_path path) t)))

(fn wait-notified [pattern]
  (helpers.expectf #(assert (accumulate [hit false _ n (ipairs (helpers.notifications))
                                         &until hit]
                              (not= nil (n.msg:find pattern)))
                            (.. "no notification matching " pattern ", got: "
                                (vim.inspect (helpers.notifications))))))

(fn count-rows [statement]
  (. (sql statement) 1 :n))

(describe "a review session from first annotation to reset"
          (fn []
            (before_each (fn []
                           (clear)
                           (helpers.setup-test-repo)
                           (helpers.setup-codeboomer)
                           (api.nvim_command "runtime plugin/codeboomer.lua")
                           (codeboomer.setup {})))
            (it "deletes the reset session with its threads and comments"
                (fn []
                  (annotate-lines files.main 10 12 "why a loop here?")
                  (annotate-file files.readme "the intro is stale")
                  (let [sid (. (review.session-for) :id)
                        line-thread (thread-on sid files.main)
                        file-thread (thread-on sid files.readme)]
                    (eq 2 (length (review.threads-for-session sid)))
                    (review.agent-reply line-thread.id
                                        "the loop batches writes")
                    (review.agent-reply file-thread.id
                                        "updated in the next commit")
                    (helpers.edit files.main)
                    (let [code-win (api.nvim_get_current_win)
                          tab (api.nvim_get_current_tabpage)]
                      (rest code-win 10)
                      (press-in-pane tab :a)
                      (type-and-submit "batch size is unbounded though")
                      (eq 3
                          (length (review.conversation-comments line-thread.id)))
                      (api.nvim_set_current_win code-win)
                      (api.nvim_command "Codeboomer ResetSession")
                      (wait-notified (: "session #%d reset" :format sid))
                      (assert.is_nil (review.session-for))
                      (eq 0 (length (review.threads-for-session sid)))
                      (eq 0 (length (review.pending-for-flush sid)))
                      (eq [""]
                          (api.nvim_buf_get_lines (api.nvim_win_get_buf (find-pane tab))
                                                  0 -1 false))
                      (assert.is_nil (review.agent-reply line-thread.id
                                                         "too late"))
                      (assert.is_nil (review.user-reply file-thread.id
                                                        "too late"))
                      (eq 0 (count-rows (.. "select count(*) as n from session where id = "
                                            sid)))
                      (eq 0 (count-rows (.. "select count(*) as n from comment_thread where session_id = "
                                            sid)))
                      (eq 0
                          (count-rows (: "select count(*) as n from comment where thread_id in (%d, %d)"
                                         :format line-thread.id file-thread.id)))
                      (annotate-lines files.main 20 20 "fresh start")
                      (let [next-sid (. (review.session-for) :id)
                            fresh-thread (thread-on next-sid files.main)]
                        (helpers.neq sid next-sid)
                        (eq 1 (length (review.threads-for-session next-sid)))
                        (assert.is_true (> fresh-thread.id file-thread.id))
                        (assert.is_nil (review.agent-reply file-thread.id
                                                           "late answer"))
                        (eq 1 (length (review.comments-for fresh-thread.id))))))))))
