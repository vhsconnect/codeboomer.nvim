;; [nfnl] codeboomer/github.fnl
;; The gh transport, both directions:
;;  - post-threads: push my unposted annotations of a PR session up
;;    as a PENDING review — a GitHub draft whose comments sit
;;    unsubmitted until approved there. Fresh threads batch into one
;;    draft review per anchor commit (so every inline comment resolves
;;    against the exact diff it was written on); replies to pulled
;;    threads post against the thread's root gh comment, immediately —
;;    the replies endpoint has no draft state. Only comments authored
;;    by me with source :user ever ship (review.pending-annotations
;;    filters) — agent and pulled rows never enter the outbox.
;;  - pull-comments: import the PR's inline comments as threads —
;;    idempotent by gh comment id, replies joined to their threads,
;;    outdated comments flagged.
;; Line numbers are the snapshot's (threads anchor to the pinned PR
;; head), and pushes are validated against the review's changed ranges
;; before the round trip — GitHub rejects inline comments off the diff,
;; so we refuse them here first.
(global vim vim)

(local git (require :codeboomer.git))
(local review (require :codeboomer.review))

(local M {})

(fn notify [msg level]
  (vim.schedule #(vim.notify msg level)))

;; vim.system, but on_exit is scheduled onto the main loop first — every
;; on_exit handler below touches the db (via git.repo-root) or fires
;; notify/autocmds, none of which are safe off the main loop
(fn system [argv opts on-exit]
  (vim.system argv opts
              (fn [obj]
                (vim.schedule #(on-exit obj)))))

;; "owner/repo" out of the common GitHub remote forms —
;;   git@github.com:owner/repo.git
;;   ssh://git@github.com/owner/repo.git
;;   https://github.com/owner/repo.git
;; anything else (gitlab, a self-hosted server, ...) yields nil
(fn parse-github-slug [url]
  (when url
    (let [path (url:match "github%.com[:/](.+)")
          slug (when path (path:gsub "%.git$" ""))]
      (when slug (slug:match "^[%w%-%_.]+/[%w%-%_.]+$")))))

;; origin's slug when origin is a GitHub remote, else the first remote
;; that points at github.com — two passes so origin is preferred
(fn github-slug []
  (var slug nil)
  (each [_ r (ipairs (or (git.remotes) []))]
    (when (and (not slug) (= r.name :origin))
      (set slug (parse-github-slug r.url))))
  (each [_ r (ipairs (or (git.remotes) []))]
    (when (not slug)
      (set slug (parse-github-slug r.url))))
  slug)

(set M.repo-slug (fn [] (github-slug)))

;; ── push ──────────────────────────────────────────────────────────

;; one pending annotation → one inline PR comment: the range becomes
;; start_line/line (equal endpoints collapse to a single line), the
;; body is the annotation's text — thread paths are already
;; repo-relative, as the API wants
(fn pr-comment [t c]
  (let [item {:path (or t.file_path "")
              :line (or t.line_end (or t.line_start 1))
              :body (or c.body "")}]
    (when (and t.line_start t.line_end (< t.line_start t.line_end))
      (set item.start_line t.line_start))
    item))

;; pending annotations grouped by anchor-commit SHA — a GitHub review
;; anchors to ONE commit, so annotations written on different commits
;; need separate reviews for their line numbers to resolve against the
;; right diff; "?" buckets annotations whose commit row is gone (posted
;; unanchored)
(fn group-pending [pending]
  (let [groups {}]
    (each [_ a (ipairs pending)]
      (let [sha (or (review.commit-sha (or a.thread.anchor_commit 0)) "?")
            entry {:item (pr-comment a.thread a.comment) :id a.comment.id}
            bucket (or (. groups sha) [])]
        (table.insert bucket entry)
        (tset groups sha bucket)))
    groups))

;; POST one draft review: gh api reads the JSON payload from stdin.
;; The payload carries no event, which GitHub reads as PENDING — the
;; comments land in a draft review, submitted on the web (comment /
;; approve / request changes) whenever you are ready. GitHub allows
;; one pending review per user and PR, so a second draft while the
;; first is unsubmitted is rejected (422). On success the annotations
;; are marked posted, so the outbox drains
(fn post-review [slug pr-number sha entries]
  (let [comments (icollect [_ e (ipairs entries)] e.item)
        ids (icollect [_ e (ipairs entries)] e.id)
        payload {:body (string.format "codeboomer review — %d annotation(s)"
                                      (length comments))
                 : comments}]
    (when (not= sha "?") (set payload.commit_id sha))
    (system [:gh
             :api
             (string.format "repos/%s/pulls/%s/reviews" slug pr-number)
             :--input
             "-"] {:stdin (vim.json.encode payload) :text true}
            (fn [obj]
              (if (= obj.code 0)
                  (let [res (vim.json.decode (or obj.stdout "{}"))]
                    (review.mark-annotations :posted ids)
                    (notify (string.format "codeboomer: drafted %d annotation(s) — pending review, submit it on GitHub\n%s"
                                           (length comments)
                                           (or res.html_url
                                               (tostring (?. res :id))))
                            vim.log.levels.INFO))
                  (notify (string.format "codeboomer: gh api failed (exit %d)\n%s"
                                         obj.code (or obj.stderr ""))
                          vim.log.levels.ERROR))))))

;; POST a reply to a pulled thread: attaches under its root gh comment
;; through the replies endpoint, one request per pending reply
(fn post-reply [slug pr-number a]
  (let [root (review.gh-root-comment-id a.thread.id)]
    (if (not root)
        (notify (string.format "codeboomer: thread #%s has no gh comment to reply to"
                               (tostring (or a.thread.id 0)))
                vim.log.levels.ERROR)
        (system [:gh
                 :api
                 (string.format "repos/%s/pulls/%s/comments/%s/replies" slug
                                pr-number root)
                 :--input
                 "-"]
                {:stdin (vim.json.encode {:body (or a.comment.body "")})
                 :text true}
                (fn [obj]
                  (if (= obj.code 0)
                      (do
                        (review.mark-annotations :posted [a.comment.id])
                        (notify "codeboomer: reply posted" vim.log.levels.INFO))
                      (notify (string.format "codeboomer: reply failed (exit %d)
%s" obj.code (or obj.stderr ""))
                              vim.log.levels.ERROR)))))))

;; pending annotations that fall outside the diff: a thread is valid
;; when its range intersects any changed range of its file. GitHub
;; rejects inline comments off the diff — we refuse them before the
;; round trip. Pure, for tests and the pre-post check
(fn M.validate-ranges [pending ranges]
  (icollect [_ a (ipairs (or pending []))]
    (let [t a.thread
          rs (and ranges (. ranges (or t.file_path "")))]
      (when (not (and rs
                      (accumulate [hit false _ [s e] (ipairs rs)]
                        (or hit
                            (and (<= s (or t.line_end 0))
                                 (>= e (or t.line_start 0)))))))
        a))))

;; push the session's unposted annotations to its PR: replies to
;; pulled threads first (replies endpoint — immediately, it has no
;; draft state), then fresh threads batched into one pending review
;; per anchor commit
(fn post-pending [session slug pending]
  (let [replies []
        news []]
    (each [_ a (ipairs pending)]
      (if (review.gh-root-comment-id a.thread.id)
          (table.insert replies a)
          (table.insert news a)))
    (each [_ a (ipairs replies)]
      (post-reply slug session.pr_number a))
    (each [sha entries (pairs (group-pending news))]
      (post-review slug session.pr_number sha entries))))

(fn post-checked [session sid slug ranges]
  (let [pending (review.pending-annotations sid :posted)]
    (if (= 0 (length pending))
        (notify "codeboomer: nothing to post — no unposted annotations"
                vim.log.levels.WARN)
        (let [invalid (if ranges (M.validate-ranges pending ranges) [])]
          (if (> (length invalid) 0)
              (notify (string.format "codeboomer: %d annotation(s) fall outside the PR diff — move or resolve them first"
                                     (length invalid))
                      vim.log.levels.ERROR)
              (post-pending session slug pending))))))

;; push the chosen session's unposted annotations to its PR.
;; opts: {:session-id :ranges} — ranges (from an open review) enable
;; the off-diff check
(fn M.post-threads [?opts]
  (let [opts (or ?opts {})
        sid (or opts.session-id (review.current-session-id))
        session (when sid (review.session-by-id sid))
        slug (github-slug)]
    (if (not sid)
        (notify "codeboomer: no review session — pick one first"
                vim.log.levels.WARN)
        (not session)
        (notify "codeboomer: session not found" vim.log.levels.ERROR)
        (not session.pr_number)
        (notify "codeboomer: the chosen session is not a PR review"
                vim.log.levels.WARN)
        (not slug)
        (notify "codeboomer: no GitHub remote in this repository"
                vim.log.levels.ERROR)
        (post-checked session sid slug opts.ranges))))

;; ── pull ──────────────────────────────────────────────────────────

;; gh api --paginate --jq '.[]' emits one JSON object per line —
;; decode each, drop what isn't an object
(fn parse-jsonl [out]
  (icollect [line (string.gmatch (or out "") "[^\r\n]+")]
    (let [(ok item) (pcall vim.json.decode line)]
      (when (and ok (= :table (type item)))
        item))))

;; payload items → rows: known gh ids are skipped (idempotent), a
;; comment with in_reply_to_id joins that thread, anything else seeds
;; one. Returns how many rows were new
(fn M.import-items [session-id items]
  (var n 0)
  (each [_ item (ipairs (or items []))]
    (when (and item.id (not (review.comment-by-gh item.id)))
      (let [parent (when item.in_reply_to_id
                     (review.thread-id-for-gh item.in_reply_to_id))]
        (if parent
            (review.import-comment parent item)
            (review.import-thread session-id item)))
      (set n (+ n 1))))
  n)

;; refresh a PR session with the PR's current inline comments — the
;; sidebar reloads via CodeboomerImported. Requires the session to
;; exist (open the PR with :Codeboomer Review first)
(fn M.pull-comments [pr-number]
  (let [slug (github-slug)
        session (review.session-for-pr pr-number)]
    (if (not slug)
        (notify "codeboomer: no GitHub remote in this repository"
                vim.log.levels.ERROR)
        (not session)
        (notify "codeboomer: no session for this PR — :Codeboomer Review it first"
                vim.log.levels.WARN)
        (system [:gh
                 :api
                 (string.format "repos/%s/pulls/%s/comments" slug pr-number)
                 :--paginate
                 :--jq
                 ".[]"] {:text true}
                (fn [obj]
                  (if (= obj.code 0)
                      (let [n (M.import-items session.id
                                              (parse-jsonl obj.stdout))]
                        (vim.api.nvim_exec_autocmds :User
                                                    {:pattern :CodeboomerImported})
                        (notify (string.format "codeboomer: pulled %d new comment(s)"
                                               n)
                                vim.log.levels.INFO))
                      (notify (string.format "codeboomer: gh api failed (exit %d)
%s" obj.code (or obj.stderr ""))
                              vim.log.levels.ERROR)))))))

M
