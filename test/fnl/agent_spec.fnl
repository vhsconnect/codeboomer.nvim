(local helpers (require :cb_helpers))

(local {: clear : eq : matches : fixtures} helpers)
(local files fixtures.files)

(local agent (helpers.module :codeboomer.agent))
(local review (helpers.module :codeboomer.review))

(helpers.env)

(describe "the agent shim"
          (fn []
            (var sid nil)

            (fn only-thread []
              (. (review.threads-for-session sid) 1))

            (before_each (fn []
                           (clear)
                           (helpers.setup-test-repo)
                           (helpers.setup-codeboomer)
                           (helpers.edit files.main)
                           (set sid (review.ensure-session))))
            (describe :comment
                      (fn []
                        (it "opens a local thread rooted in the agent's finding"
                            (fn []
                              (let [(ok msg) (agent.run [:comment
                                                         files.main
                                                         :10-12
                                                         :off
                                                         :by
                                                         :one])
                                    thread (only-thread)
                                    root (. (review.conversation-comments thread.id)
                                            1)]
                                (assert.is_true ok)
                                (matches "^opened thread #%d+ on main%.txt:10%-12$"
                                         msg)
                                (eq :local thread.kind)
                                (eq [10 12] [thread.line_start thread.line_end])
                                (eq (helpers.content-snapshot 10 12)
                                    thread.code_snapshot)
                                (eq [:agent "off by one"]
                                    [root.source root.body]))))
                        (it "takes a single line"
                            (fn []
                              (agent.run [:comment files.main :7 :note])
                              (let [thread (only-thread)]
                                (eq [7 7] [thread.line_start thread.line_end]))))
                        (it "promotes like an annotation"
                            (fn []
                              (agent.run [:comment files.main :10-12 :finding])
                              (assert.is_not_nil (review.promote (. (only-thread)
                                                                    :id)
                                                                 "final wording"
                                                                 sid nil))
                              (eq 1 (length (review.pending-for-post sid)))))
                        (it "stays out of the flush outbox"
                            (fn []
                              (agent.run [:comment files.main :10-12 :finding])
                              (eq 0 (length (review.pending-for-flush sid)))))
                        (it "refuses a range past the end of the file"
                            (fn []
                              (let [(ok msg) (agent.run [:comment
                                                         files.main
                                                         :99-101
                                                         :finding])]
                                (assert.is_false ok)
                                (matches "out of range" msg)
                                (eq 0 (length (review.threads-for-session sid))))))
                        (it "refuses a malformed range"
                            (fn []
                              (assert.is_false (agent.run [:comment
                                                           files.main
                                                           :12-10
                                                           :finding]))
                              (assert.is_false (agent.run [:comment
                                                           files.main
                                                           :ten
                                                           :finding]))))
                        (it "refuses files outside the work tree"
                            (fn []
                              (helpers.write-to-file :../outside.txt ["line 1"])
                              (let [(ok msg) (agent.run [:comment
                                                         :../outside.txt
                                                         :1
                                                         :finding])]
                                (assert.is_false ok)
                                (matches "outside the work tree" msg))
                              (let [(ok msg) (agent.run [:comment
                                                         :/etc/hostname
                                                         :1
                                                         :finding])]
                                (assert.is_false ok)
                                (matches "outside the work tree" msg))))
                        (it "refuses a directory"
                            (fn []
                              (let [(ok msg) (agent.run [:comment
                                                         :.git
                                                         :1
                                                         :finding])]
                                (assert.is_false ok)
                                (matches "not a file" msg))))
                        (it "refuses an empty comment"
                            (fn []
                              (assert.is_false (agent.run [:comment
                                                           files.main
                                                           :10]))))))
            (describe :file-comment
                      (fn []
                        (it "opens a whole-file thread"
                            (fn []
                              (let [(ok msg) (agent.run [:file-comment
                                                         files.readme
                                                         :needs
                                                         :a
                                                         :section])
                                    thread (only-thread)]
                                (assert.is_true ok)
                                (matches "^opened thread #%d+ on README%.md$"
                                         msg)
                                (eq [:file files.readme]
                                    [thread.type thread.file_path])
                                (eq :agent
                                    (. (review.conversation-comments thread.id)
                                       1 :source)))))
                        (it "refuses a missing file"
                            (fn []
                              (assert.is_false (agent.run [:file-comment
                                                           :nope.txt
                                                           :finding]))))))
            (it "rejects unknown verbs"
                (fn []
                  (let [(ok msg) (agent.run [:shout :hello])]
                    (assert.is_false ok)
                    (matches "expected reply, comment or file%-comment" msg))))
            (describe :rpc
                      (fn []
                        (it "answers help with the usage text"
                            (fn []
                              (matches "usage: codeboomer%-agent" (agent.rpc))))
                        (it "posts a comment into the live session and announces it"
                            (fn []
                              (helpers.exec_lua (fn []
                                                  (set _G.agentposted false)
                                                  (vim.api.nvim_create_autocmd :User
                                                                               {:pattern :CodeboomerAgentPosted
                                                                                :callback #(set _G.agentposted
                                                                                                true)})))
                              (let [args (.. "comment " files.main
                                             " 5 posted over rpc")
                                    b64 (helpers.exec_lua (fn [a]
                                                            (vim.base64.encode a))
                                                          args)
                                    msg (agent.rpc b64)
                                    thread (only-thread)
                                    root (. (review.conversation-comments thread.id)
                                            1)]
                                (matches "^codeboomer%-agent: opened thread #%d+"
                                         msg)
                                (eq [:agent "posted over rpc"]
                                    [root.source root.body])
                                ;; the evented refresh — no cursor-move polling
                                (helpers.expectf #(helpers.exec_lua "return _G.agentposted")))))
                        (it "aborts the remote call on a refused verb, for the shim's fallback"
                            (fn []
                              (let [b64 (helpers.exec_lua (fn [a]
                                                            (vim.base64.encode a))
                                                          "reply 999 nope")]
                                (assert.is_false (pcall agent.rpc b64)))))
                        (it "bakes the fast path into the generated shim"
                            (fn []
                              ;; the shim regenerates on module load
                              (agent.rpc)
                              (let [file (io.open (.. helpers.data-home
                                                      :/nvim/codeboomer-agent))
                                    shim (file:read :*a)]
                                (file:close)
                                (assert (shim:find "--server \"$NVIM\"" 1 true))
                                (assert (shim:find "codeboomer.agent').rpc('$b64')"
                                                   1 true))
                                ;; the headless run remains the fallback
                                (assert (shim:find :--headless 1 true)))))))))
