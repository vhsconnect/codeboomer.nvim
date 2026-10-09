(local helpers (require :cb_helpers))

(local {: clear : eq : fixtures} helpers)
(local files fixtures.files)

(local review (helpers.module :codeboomer.review))
(local github (helpers.module :codeboomer.github))

(helpers.env)

(describe "review threads"
          (fn []
            (var sid nil)

            (fn threads-on [path]
              (vim.tbl_filter #(= $1.file_path path)
                              (review.threads-for-session sid)))

            (before_each (fn []
                           (clear)
                           (helpers.setup-test-repo)
                           (helpers.setup-codeboomer)
                           (helpers.edit files.main)
                           (set sid (review.ensure-session))))
            (describe "an annotation"
                      (fn []
                        (var thread nil)
                        (before_each (fn []
                                       (review.user-comment sid files.main 10
                                                            12 "code A"
                                                            "annotation A")
                                       (set thread
                                            (. (review.threads-for-session sid)
                                               1))))
                        (it "is born a local root"
                            (fn []
                              (eq 1 (length (review.threads-for-session sid)))
                              (eq :local thread.kind)))
                        (it "interleaves the conversation by creation"
                            (fn []
                              (review.agent-reply thread.id "agent pushback")
                              (review.user-reply thread.id "user negotiation")
                              (eq 3
                                  (length (review.conversation-comments thread.id)))))
                        (it "stays off the posting outbox until promoted"
                            (fn []
                              (review.agent-reply thread.id "agent pushback")
                              (review.user-reply thread.id "user negotiation")
                              (assert.is_nil (review.twin thread.id))
                              (eq 0 (length (review.pending-for-post sid)))
                              (eq 2 (length (review.pending-for-flush sid)))))))
            (describe :promote
                      (fn []
                        (var thread nil)
                        (var twin-id nil)
                        (before_each (fn []
                                       (review.user-comment sid files.main 10
                                                            12
                                                            (helpers.content-snapshot 10
                                                                                      12)
                                                            "annotation A")
                                       (set thread
                                            (. (review.threads-for-session sid)
                                               1))
                                       (review.agent-reply thread.id
                                                           "agent pushback")
                                       (review.user-reply thread.id
                                                          "user negotiation")
                                       (set twin-id
                                            (review.promote thread.id
                                                            "final wording" sid
                                                            nil))))
                        (it "creates the review half in the given session"
                            (fn []
                              (let [twin (review.twin thread.id)]
                                (eq :review twin.kind)
                                (eq twin-id twin.id)
                                (eq sid twin.session_id))))
                        (it "refuses a second promote and empty text"
                            (fn []
                              (assert.is_nil (review.promote thread.id :again
                                                             sid nil))
                              (assert.is_nil (review.promote 999999 "" sid nil))))
                        (it "spans the conversation across both halves"
                            (fn []
                              (eq 4
                                  (length (review.conversation-comments thread.id)))))
                        (it "puts only the promoted comment in the posting outbox"
                            (fn []
                              (let [post (review.pending-for-post sid)]
                                (eq 1 (length post))
                                (eq "final wording" (. post 1 :comment :body))
                                (eq twin-id (. post 1 :thread :id))
                                (eq 3 (length (review.pending-for-flush sid))))))
                        (it "queues replies on the review half for posting"
                            (fn []
                              (review.user-reply twin-id "reviewer reply")
                              (eq 2 (length (review.pending-for-post sid)))))
                        (it "rewrites the promoted comment in place on edit"
                            (fn []
                              (review.user-reply twin-id "reviewer reply")
                              (let [unposted (review.unposted-user-comments twin-id)]
                                (eq 2 (length unposted))
                                (eq "final wording" (. unposted 1 :body))
                                (review.update-comment-body (. unposted 1 :id)
                                                            "final wording v2"))
                              (let [post (review.pending-for-post sid)]
                                (eq 2 (length post))
                                (eq "final wording v2"
                                    (. post 1 :comment :body)))))
                        (it "folds the pair into one logical thread"
                            (fn []
                              (eq 1 (length (review.threads-for-session sid)))))
                        (it "resolves both halves together"
                            (fn []
                              (review.resolve-thread thread.id)
                              (eq 0 (length (review.threads-for-session sid)))
                              (eq 0
                                  (length (review.review-rows-for-session sid)))
                              (eq 0 (length (review.pending-for-post sid)))))))
            (describe "a pulled thread"
                      (fn []
                        (var pulled nil)
                        (before_each (fn []
                                       (set pulled
                                            (review.import-thread sid
                                                                  fixtures.pulled-item))))
                        (it "is born a review thread"
                            (fn []
                              (eq :review
                                  (. (review.review-rows-for-session sid) 1
                                     :kind))))
                        (it "diverts agent replies to a fresh local twin"
                            (fn []
                              (review.agent-reply pulled "agent take")
                              (let [local-twin (review.twin pulled)]
                                (eq :local local-twin.kind)
                                (eq 1 (length (review.comments-for pulled)))
                                (eq 1
                                    (length (review.comments-for local-twin.id)))
                                (eq (tostring fixtures.pulled-item.id)
                                    (review.gh-root-comment-id pulled))
                                (eq 0 (length (review.pending-for-post sid))))))))
            (describe "a posted comment coming home"
                      (fn []
                        (local item fixtures.come-home-item)
                        (var thread nil)
                        (var posted nil)
                        (before_each (fn []
                                       (review.user-comment sid files.readme 5
                                                            5
                                                            (helpers.content-snapshot 5
                                                                                      5)
                                                            item.body)
                                       (set thread
                                            (. (threads-on files.readme) 1))
                                       (review.promote thread.id item.body sid
                                                       nil)
                                       (set posted
                                            (. (review.pending-for-post sid) 1
                                               :comment))
                                       (review.mark-annotations :posted
                                                                [posted.id])))
                        (it "matches back onto its row"
                            (fn []
                              (eq item.body posted.body)
                              (eq posted.id
                                  (. (review.match-posted-comment sid item) :id))))
                        (it "is stamped instead of duplicated, idempotently"
                            (fn []
                              (eq 1 (github.import-items sid [item]))
                              (eq 0 (github.import-items sid [item]))
                              (assert.is_not_nil (review.comment-by-gh item.id))
                              (eq 1 (length (threads-on files.readme)))
                              (eq (tostring item.id)
                                  (review.gh-root-comment-id (. (review.twin thread.id)
                                                                :id)))))
                        (it "matches by its original line after new commits move it"
                            (fn []
                              (let [drifted (vim.tbl_extend :force item
                                                            {:line 40
                                                             :original_line item.line})]
                                (eq posted.id
                                    (. (review.match-posted-comment sid drifted)
                                       :id)))))))
            (it "matches a posted file comment coming home without a line"
                (fn []
                  (review.file-comment sid files.readme "whole-file note")
                  (let [thread (. (threads-on files.readme) 1)]
                    (review.promote thread.id "whole-file note" sid nil)
                    (let [posted (. (review.pending-for-post sid) 1 :comment)]
                      (review.mark-annotations :posted [posted.id])
                      (eq posted.id (. (review.match-posted-comment sid
                                                                    {:id 988
                                                                     :subject_type :file
                                                                     :path files.readme
                                                                     :body "whole-file note"})
                                       :id))))))
            (it "imports an outdated comment whose line is null"
                (fn []
                  (let [[item] (github.parse-jsonl fixtures.outdated-item-jsonl)]
                    (eq nil item.line)
                    (eq 1 (github.import-items sid [item]))
                    (eq 7 (. (threads-on files.readme) 1 :line_start)))))
            (it "refuses threads outside the diff hunks"
                (fn []
                  (let [thread {:file_path files.readme
                                :line_start 5
                                :line_end 5}]
                    (eq true
                        (github.thread-off-diff thread {files.readme [[1 4]]}))
                    (eq false
                        (github.thread-off-diff thread {files.readme [[1 9]]})))))
            (describe :delete-session
                      (fn []
                        (it "deletes threads and their comments"
                            (fn []
                              (review.user-comment sid files.readme 90 91
                                                   "code C" "doomed session")
                              (let [thread (. (review.threads-for-session sid)
                                              1)]
                                (review.delete-session sid)
                                (eq 0 (length (review.threads-for-session sid)))
                                (eq 0
                                    (length (review.review-rows-for-session sid)))
                                (eq 0 (length (review.comments-for thread.id)))
                                (assert.is_nil (review.session-by-id sid)))))
                        (it "detaches a twin promoted into another session"
                            (fn []
                              (review.user-comment sid files.main 10 12
                                                   (helpers.content-snapshot 10
                                                                             12)
                                                   "annotation A")
                              (let [thread (. (review.threads-for-session sid)
                                              1)]
                                (helpers.git :checkout :-q :-b :other)
                                (helpers.api.nvim_command :edit!)
                                (let [other (review.ensure-session)
                                      twin-id (review.promote thread.id
                                                              "final wording"
                                                              other nil)]
                                  (review.delete-session sid)
                                  (let [roots (review.threads-for-session other)]
                                    (eq 1 (length roots))
                                    (eq twin-id (. roots 1 :id)))))))
                        (it "leaves the branch session-less even with a PR bound"
                            (fn []
                              (review.set-session-pr sid 4242)
                              (review.delete-session sid)
                              (assert.is_nil (review.session-for))
                              (helpers.neq sid (review.ensure-session))))
                        (it "leaves other sessions alone"
                            (fn []
                              (review.user-comment sid files.main 1 1 :code
                                                   "keep me")
                              (helpers.git :checkout :-q :-b :other)
                              (helpers.api.nvim_command :edit!)
                              (let [other (review.ensure-session)]
                                (helpers.neq sid other)
                                (review.delete-session other)
                                (assert.is_not_nil (review.session-by-id sid))
                                (eq 1 (length (review.threads-for-session sid))))))))))
