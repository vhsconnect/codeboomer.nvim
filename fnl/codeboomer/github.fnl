;; [nfnl] codeboomer/github.fnl
;; Bindings for pushing local review threads to a GitHub pull request
;; through the `gh` CLI. NOT wired into any command or keymap yet —
;; this module only provides the primitives.
;;
;; The GitHub target is derived from the git remotes plus a branch: the
;; repo slug comes from whichever remote points at github.com (origin
;; wins when it is one; repos mirrored to a self-hosted origin still
;; resolve through their github remote), and the PR from that branch's
;; open pull request. Threads are posted as PR reviews — one review per
;; anchor commit, so every inline comment resolves against the exact
;; diff it was annotated on. Line numbers are the local DB's; GitHub
;; validates them against the PR diff and rejects comments on lines
;; that are not part of it (the error surfaces via vim.notify).
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

;; one local thread → one inline PR comment: the range becomes
;; start_line/line (equal endpoints collapse to a single line), the
;; body carries every local comment of the thread verbatim, oldest first
(fn review-comment [t]
  (let [bodies (icollect [_ c (ipairs (review.comments-for (or t.id 0)))]
                 (or c.body ""))
        pr-comment {:path (or t.file_path "")
                    :line (or t.line_end (or t.line_start 1))
                    :body (table.concat bodies "\n\n")}]
    (when (and t.line_start t.line_end (< t.line_start t.line_end))
      (set pr-comment.start_line t.line_start))
    pr-comment))

;; threads grouped by anchor-commit SHA — a GitHub review anchors to
;; ONE commit, so threads annotated on different commits need separate
;; reviews for their line numbers to resolve against the right diff;
;; "?" buckets threads whose commit row is gone (posted unanchored)
(fn group-by-commit [threads]
  (let [groups {}]
    (each [_ t (ipairs threads)]
      (let [sha (or (review.commit-sha (or t.anchor_commit 0)) "?")
            bucket (or (. groups sha) [])]
        (table.insert bucket t)
        (tset groups sha bucket)))
    groups))

;; POST one review: gh api reads the JSON payload from stdin
(fn post-review [slug pr-number event sha threads]
  (let [comments (icollect [_ t (ipairs threads)] (review-comment t))
        payload {:body (string.format "codeboomer review — %d thread(s)"
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
                        (notify (string.format "codeboomer: posted %d comment(s) — %s"
                                               (length comments)
                                               (or res.html_url
                                                   (tostring (?. res :id))))
                                vim.log.levels.INFO))
                      (notify (string.format "codeboomer: gh api failed (exit %d)
%s" obj.code (or obj.stderr ""))
                              vim.log.levels.ERROR))))))

;; post every thread of a review session to the branch's open PR, one
;; review per anchor commit. opts: {:session-id :branch :event} — event
;; is the GitHub review event (:COMMENT default, also :REQUEST_CHANGES,
;; :APPROVE)
(fn M.post-threads [?opts]
  (let [opts (or ?opts {})
        (ok sid-default) (pcall review.active-session-id)
        sid (or opts.session-id (if ok sid-default nil))
        branch (or opts.branch (git.branch-name))
        slug (github-slug)]
    (if (not ok)
        (notify (.. "codeboomer: " (tostring sid-default)) vim.log.levels.ERROR)
        (not slug)
        (notify "codeboomer: no GitHub remote in this repository"
                vim.log.levels.ERROR)
        (not sid)
        (notify "codeboomer: no review session to post" vim.log.levels.WARN)
        (let [threads (review.threads-for-session sid)]
          (if (= 0 (length threads))
              (notify "codeboomer: session has no threads" vim.log.levels.WARN)
              (M.pr-for-branch branch
                               (fn [pr]
                                 (if pr
                                     (each [sha ts (pairs (group-by-commit threads))]
                                       (post-review slug pr.number
                                                    (or opts.event :COMMENT) sha
                                                    ts))
                                     (notify (.. "codeboomer: no open PR for "
                                                 (or branch "?"))
                                             vim.log.levels.WARN)))))))))

M
