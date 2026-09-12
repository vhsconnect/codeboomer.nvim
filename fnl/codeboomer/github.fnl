;; [nfnl] codeboomer/github.fnl
;; Bindings for pushing review annotations to a GitHub pull request
;; through the `gh` CLI. NOT wired into any command or keymap yet —
;; this module only provides the primitives.
;;
;; The GitHub target is derived from the git remotes plus a branch: the
;; repo slug comes from whichever remote points at github.com (origin
;; wins when it is one; repos mirrored to a self-hosted origin still
;; resolve through their github remote), and the PR from that branch's
;; open pull request. Only UNPOSTED annotations are sent (the DB is the
;; outbox — review.pending-annotations picks them), one review per
;; anchor commit so every inline comment resolves against the exact
;; diff it was annotated on; on success the rows are marked posted.
;; Line numbers are the local DB's; GitHub validates them against the
;; PR diff and rejects comments on lines that are not part of it (the
;; error surfaces via vim.notify).
(global vim vim)

(local git (require :codeboomer.git))
(local review (require :codeboomer.review))

(local M {})

(fn notify [msg level]
  (vim.schedule #(vim.notify msg level)))

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

;; `gh pr view --json` output → {:number N :url "..."} (nil when the
;; JSON carries no number)
(fn parse-pr [stdout]
  (let [pr (vim.json.decode (or stdout "{}"))]
    (when pr.number {:number pr.number :url pr.url})))

;; the open PR of a branch (default: HEAD's), nil when the branch has
;; none — async, ?then receives the result
(fn M.pr-for-branch [?branch ?then]
  (let [branch (or ?branch (git.branch-name))
        slug (github-slug)]
    (if (not branch)
        (notify "codeboomer: detached HEAD — no branch to look up"
                vim.log.levels.ERROR)
        (not slug)
        (notify "codeboomer: no GitHub remote in this repository"
                vim.log.levels.ERROR)
        (vim.system [:gh :pr :view branch :--repo slug :--json "number,url"]
                    {:text true}
                    (fn [obj]
                      (when ?then
                        (?then (if (= obj.code 0)
                                   (parse-pr obj.stdout)
                                   nil))))))))

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

;; POST one review: gh api reads the JSON payload from stdin — on
;; success the annotations are marked posted, so the outbox drains
(fn post-review [slug pr-number event sha entries]
  (let [comments (icollect [_ e (ipairs entries)] e.item)
        ids (icollect [_ e (ipairs entries)] e.id)
        payload {:body (string.format "codeboomer review — %d annotation(s)"
                                      (length comments))
                 : event
                 : comments}]
    (when (not= sha "?") (set payload.commit_id sha))
    (vim.system [:gh
                 :api
                 (string.format "repos/%s/pulls/%s/reviews" slug pr-number)
                 :--input
                 "-"]
                {:input (vim.json.encode payload) :text true}
                (fn [obj]
                  (if (= obj.code 0)
                      (let [res (vim.json.decode (or obj.stdout "{}"))]
                        (review.mark-annotations :posted ids)
                        (notify (string.format "codeboomer: posted %d annotation(s) — %s"
                                               (length comments)
                                               (or res.html_url
                                                   (tostring (?. res :id))))
                                vim.log.levels.INFO))
                      (notify (string.format "codeboomer: gh api failed (exit %d)
%s" obj.code (or obj.stderr ""))
                              vim.log.levels.ERROR))))))

;; post every UNPOSTED annotation of a review session to the branch's
;; open PR, one review per anchor commit. opts: {:session-id :branch
;; :event} — event is the GitHub review event (:COMMENT default, also
;; :REQUEST_CHANGES, :APPROVE)
(fn M.post-threads [?opts]
  (let [opts (or ?opts {})
        sid (or opts.session-id (review.current-session-id))
        branch (or opts.branch (git.branch-name))
        slug (github-slug)]
    (if (not slug)
        (notify "codeboomer: no GitHub remote in this repository"
                vim.log.levels.ERROR)
        (not sid)
        (notify "codeboomer: no review session — pick one first"
                vim.log.levels.WARN)
        (let [pending (review.pending-annotations sid :posted)]
          (if (= 0 (length pending))
              (notify "codeboomer: nothing to post — no unposted annotations"
                      vim.log.levels.WARN)
              (M.pr-for-branch branch
                               (fn [pr]
                                 (if pr
                                     (each [sha entries (pairs (group-pending pending))]
                                       (post-review slug pr.number
                                                    (or opts.event :COMMENT) sha
                                                    entries))
                                     (notify (.. "codeboomer: no open PR for "
                                                 (or branch "?"))
                                             vim.log.levels.WARN)))))))))

M
