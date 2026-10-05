(local helpers (require :cb_helpers))

(local {: api : clear : eq : matches : fixtures} helpers)
(local exec-lua helpers.exec_lua)
(local files fixtures.files)

(local review (helpers.module :codeboomer.review))
(local sidebar (helpers.module :codeboomer.sidebar))

(local pane-name-pattern "^codeboomer://review%-comments")
(local wide-header "^#%d+  main%.txt:1%-69  %(")
(local narrow-header "^#%d+  main%.txt:3%-3  %(")

(helpers.env)

(fn rest [win line]
  (exec-lua (fn [win line]
              (vim.api.nvim_win_set_cursor win [line 0])
              (vim.cmd "doautocmd CursorMoved")
              (vim.wait 300)) win line))

(fn settle []
  (exec-lua #(vim.wait 300)))

(fn find-pane [tab]
  (exec-lua (fn [tab pattern]
              (accumulate [found nil _ w (ipairs (vim.api.nvim_tabpage_list_wins tab))
                           &until found]
                (when (: (vim.api.nvim_buf_get_name (vim.api.nvim_win_get_buf w))
                         :find pattern)
                  w))) tab pane-name-pattern))

(fn open-file [path]
  (api.nvim_command (.. "edit " path))
  (api.nvim_command "doautocmd BufEnter")
  (settle))

(describe :sidebar
          (fn []
            (var code-win nil)
            (var tab1 nil)
            (var sid nil)

            (fn pane-lines []
              (api.nvim_buf_get_lines (api.nvim_win_get_buf (find-pane tab1)) 0
                                      -1 false))

            (fn thread-at [line-start line-end]
              (accumulate [found nil _ t (ipairs (review.threads-for-session sid))
                           &until found]
                (when (and (= t.line_start line-start) (= t.line_end line-end))
                  t)))

            (fn press-in-pane [key]
              (exec-lua (fn [win key]
                          (vim.api.nvim_set_current_win win)
                          (vim.api.nvim_win_set_cursor win [1 0])
                          ((. (vim.fn.maparg key :n false true) :callback))
                          (vim.api.nvim_buf_get_lines (vim.api.nvim_win_get_buf win)
                                                      0 -1 false))
                        (find-pane tab1) key))

            (before_each (fn []
                           (clear)
                           (helpers.setup-test-repo)
                           (helpers.setup-codeboomer)
                           (helpers.edit files.main)
                           (set code-win (api.nvim_get_current_win))
                           (set tab1 (api.nvim_get_current_tabpage))
                           (set sid (review.ensure-session))
                           (review.user-comment sid files.main 3 3 "code A"
                                                :testing)
                           (review.user-comment sid files.main 1 69
                                                (helpers.content-snapshot 1 69)
                                                "another test")
                           (review.user-reply (. (thread-at 3 3) :id) "a reply")
                           (sidebar.reload-threads)
                           (settle)
                           (case (find-pane tab1)
                             pane (api.nvim_win_close pane true))))
            (describe "rest detection"
                      (fn []
                        (it "opens the pane after resting in a range"
                            (fn []
                              (rest code-win 3)
                              (assert.is_not_nil (find-pane tab1))))
                        (it "waits out the rest delay before opening"
                            (fn []
                              (api.nvim_win_set_cursor code-win [3 0])
                              (api.nvim_command "doautocmd CursorMoved")
                              (assert.is_nil (find-pane tab1))
                              (settle)
                              (assert.is_not_nil (find-pane tab1))))
                        (it "keeps the cursor in the code window"
                            (fn []
                              (rest code-win 3)
                              (eq code-win (api.nvim_get_current_win))))
                        (it "renders into a nofile, unmodifiable buffer"
                            (fn []
                              (rest code-win 3)
                              (let [buf (api.nvim_win_get_buf (find-pane tab1))]
                                (eq :nofile
                                    (api.nvim_get_option_value :buftype {: buf}))
                                (eq false
                                    (api.nvim_get_option_value :modifiable
                                                               {: buf})))))
                        (it "shows the earliest covering thread where ranges overlap"
                            (fn []
                              (rest code-win 3)
                              (let [lines (pane-lines)]
                                (matches wide-header (. lines 1))
                                (eq "" (. lines 2))
                                (matches "^%[%w+%] " (. lines 3)))))
                        (it "shows the only covering thread off the overlap"
                            (fn []
                              (rest code-win 12)
                              (matches wide-header (. (pane-lines) 1))))
                        (it "keeps the last block when the cursor leaves every range"
                            (fn []
                              (rest code-win 3)
                              (let [last (pane-lines)]
                                (rest code-win 100)
                                (eq last (pane-lines)))))))
            (describe "entering files"
                      (fn []
                        (it "opens no pane in another tab's threadless file"
                            (fn []
                              (rest code-win 3)
                              (api.nvim_command :tabnew)
                              (api.nvim_command "doautocmd TabEnter")
                              (let [tab2 (api.nvim_get_current_tabpage)]
                                (open-file files.readme)
                                (assert.is_nil (find-pane tab2))
                                (assert.is_not_nil (find-pane tab1)))))
                        (it "opens the pane only for files with threads"
                            (fn []
                              (open-file files.readme)
                              (assert.is_nil (find-pane tab1))
                              (open-file files.main)
                              (matches wide-header (. (pane-lines) 1))))
                        (it "shows a single thread on file enter — the file's first"
                            (fn []
                              (open-file files.main)
                              (let [headers (icollect [_ l (ipairs (pane-lines))]
                                              (when (l:match "^#%d+  ") l))]
                                (eq 1 (length headers))
                                (matches wide-header (. headers 1)))))
                        (it "keeps the current thread on screen in a threadless file"
                            (fn []
                              (rest code-win 3)
                              (let [before (pane-lines)]
                                (open-file files.readme)
                                (eq before (pane-lines)))))))
            (describe "opening a repo"
                      (fn []
                        (it "opens the pane with the session's first thread whatever buffer starts"
                            (fn []
                              (open-file files.readme)
                              (api.nvim_exec_autocmds :VimEnter
                                                      {:group :codeboomer-review-pane})
                              (settle)
                              (assert.is_not_nil (find-pane tab1))
                              (matches wide-header (. (pane-lines) 1))))
                        (it "opens no pane when the branch has no session"
                            (fn []
                              (review.delete-session sid)
                              (sidebar.reload-threads)
                              (open-file files.readme)
                              (api.nvim_exec_autocmds :VimEnter
                                                      {:group :codeboomer-review-pane})
                              (settle)
                              (assert.is_nil (find-pane tab1))))))
            (describe "closing by hand"
                      (fn []
                        (it "stays closed until the cursor rests again"
                            (fn []
                              (rest code-win 3)
                              (api.nvim_win_close (find-pane tab1) true)
                              (assert.is_nil (find-pane tab1))
                              (rest code-win 3)
                              (assert.is_not_nil (find-pane tab1))))))
            (describe "floating windows over the pane"
                      (fn []
                        (it "keeps the thread while a nofile float holds focus"
                            (fn []
                              (rest code-win 3)
                              (api.nvim_set_current_win (find-pane tab1))
                              (let [before (pane-lines)
                                    ;; the input and the fzf pickers open as
                                    ;; floating nofile buffers — entering one
                                    ;; fires BufEnter, which must not read as
                                    ;; leaving the session
                                    fbuf (api.nvim_create_buf false true)
                                    fwin (api.nvim_open_win fbuf true
                                                            {:relative :editor
                                                             :row 1
                                                             :col 1
                                                             :width 10
                                                             :height 2})]
                                (api.nvim_command "doautocmd BufEnter")
                                (eq before (pane-lines))
                                (api.nvim_win_close fwin true)
                                (settle)
                                (eq before (pane-lines)))))))
            (describe :promotion
                      (fn []
                        (var wide nil)
                        (before_each (fn []
                                       (set wide (thread-at 1 69))
                                       (review.set-session-pr sid
                                                              fixtures.pr.number)
                                       (helpers.fake-gh-text (.. :pr-diff-
                                                                 fixtures.pr.number
                                                                 :.txt)
                                                             fixtures.pr-diff)
                                       (rest code-win 40)
                                       (press-in-pane :p)
                                       (exec-lua #(vim.wait 100))))
                        (it "marks the header as promoted"
                            (fn []
                              (matches :promoted (. (pane-lines) 1))))
                        (it "creates the review half with the promoted comment"
                            (fn []
                              (let [twin (review.twin wide.id)]
                                (eq :review twin.kind)
                                (eq 1 (length (review.pending-for-post sid)))
                                (eq 2
                                    (length (review.conversation-comments twin.parent_id))))))
                        (it "queues replies on the review half for posting"
                            (fn []
                              (review.user-reply (. (review.twin wide.id) :id)
                                                 "reviewer reply")
                              (eq 2 (length (review.pending-for-post sid)))))
                        (it "lands outside replies on the idle refresh without a cursor rest"
                            (fn []
                              (api.nvim_set_current_win code-win)
                              (rest code-win 100)
                              (review.user-reply (. (review.twin wide.id) :id)
                                                 "idle refresh reply")
                              (sidebar.reload-threads)
                              (settle)
                              (let [lines (pane-lines)]
                                (assert.is_true (vim.list_contains lines
                                                                   "idle refresh reply"))
                                (matches wide-header (. lines 1)))))))
            (describe :navigation
                      (fn []
                        (before_each (fn []
                                       (rest code-win 3)))
                        (it "renders the keymap footer"
                            (fn []
                              (assert.is_true (accumulate [hit false _ l (ipairs (pane-lines))
                                                           &until hit]
                                                (not= nil
                                                      (l:match "^── keys "))))))
                        (it "steps through threads with n and wraps forever"
                            (fn []
                              (matches "3%-3" (. (press-in-pane :n) 1))
                              (matches "1%-69" (. (press-in-pane :n) 1))
                              (matches "3%-3" (. (press-in-pane :n) 1))
                              (matches "1%-69" (. (press-in-pane :n) 1))))
                        (it "lands the code window on the cycled thread's file"
                            (fn []
                              (review.user-comment sid files.readme 5 5
                                                   "readme code" :elsewhere)
                              (sidebar.reload-threads)
                              (rest code-win 3)
                              (press-in-pane :n)
                              (matches "README%.md:5%-5"
                                       (. (press-in-pane :n) 1))
                              (matches (.. files.readme "$")
                                       (api.nvim_buf_get_name (api.nvim_win_get_buf code-win)))))
                        (it "cycles from a threadless file too"
                            (fn []
                              (rest code-win 3)
                              (open-file files.readme)
                              (matches "3%-3" (. (press-in-pane :n) 1))
                              (matches (.. files.main "$")
                                       (api.nvim_buf_get_name (api.nvim_win_get_buf code-win)))))
                        (it "lands on the last line when a thread outlives its lines"
                            (fn []
                              (api.nvim_buf_set_lines (api.nvim_win_get_buf code-win)
                                                      2 -1 false [])
                              (matches "3%-3" (. (press-in-pane :n) 1))
                              (eq [2 0] (api.nvim_win_get_cursor code-win))))
                        (it "opens the cycled thread's file in the linked worktree it was read from"
                            (fn []
                              (let [wt (.. helpers.scratch :/wt)
                                    feature-file :feature.txt]
                                (helpers.git :worktree :add :-q :-b :feature wt)
                                (helpers.write-to-file (.. :../wt/ feature-file)
                                                       ["feature only"])
                                (helpers.git :-C wt :add feature-file)
                                (helpers.git :-C wt :commit :-q :-m :feature)
                                (open-file (.. wt "/" files.main))
                                (let [wt-sid (review.ensure-session)]
                                  (review.user-comment wt-sid files.main 3 3
                                                       "code A" :testing)
                                  (review.user-comment wt-sid feature-file 1 1
                                                       "feature only" :elsewhere))
                                (sidebar.reload-threads)
                                (rest code-win 3)
                                (matches "feature%.txt:1%-1"
                                         (. (press-in-pane :n) 1))
                                (eq (.. wt "/" feature-file)
                                    (api.nvim_buf_get_name (api.nvim_win_get_buf code-win)))
                                (matches "main%.txt:3%-3"
                                         (. (press-in-pane :n) 1)))))))
            (describe :resolve
                      (fn []
                        (before_each (fn []
                                       (rest code-win 3)))
                        (it "hands the pane to the next covering thread"
                            (fn []
                              (press-in-pane :q)
                              (settle)
                              (matches narrow-header (. (pane-lines) 1))))
                        (it "blanks the pane but keeps it open after the last thread"
                            (fn []
                              (press-in-pane :q)
                              (settle)
                              (press-in-pane :q)
                              (settle)
                              (assert.is_not_nil (find-pane tab1))
                              (eq [""] (pane-lines))))))))
