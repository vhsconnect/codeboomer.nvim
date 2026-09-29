;; [nfnl] codeboomer/review-mode.fnl
;; The PR half of codeboomer's review flow. There is no worktree and
;; no snapshot to set up: you review whatever you have checked out —
;; the PR branch, a particular commit, a dirty working tree — by
;; annotating it where it stands.
;; :Codeboomer Review picks a PR and binds this branch's session to
;; it:
;; the PR's inline comments come down as threads and the PR's diff is
;; parsed once for the off-diff gate; the comments pane follows the
;; cursor from there. Promote (the pane's p key) creates the shipping
;; half in the PR session; PostReview pushes it up — see github.fnl
(global vim vim)

(local git (require :codeboomer.git))
(local review (require :codeboomer.review))
(local sidebar (require :codeboomer.sidebar))
(local github (require :codeboomer.github))

(local M {})

;; the open PR review: {:pr-number :session-id :ranges} — nil when
;; none is open. ranges is the PR's own diff (gh pr diff) as
;; {rel-path [[start last] ...]}, what the off-diff gate reads; nil
;; until it loads (or for good when gh cannot produce it), in which
;; case the gate steps aside and GitHub's own rejection surfaces at
;; post time
(var current nil)

;; promotion (the pane's p key) reads this hook with the branch
;; session row the sidebar resolved: PR-bound sessions promote, and
;; the open PR review's diff ranges ride along when it is the same
;; session. A soft-deleted session reads as gone here, refusing p
;; cleanly
(sidebar.set-promote-context
  (fn [session]
    (when (and session session.pr_number)
      (if (and current (= session.id current.session-id))
          {:session-id session.id :head-ranges current.ranges}
          {:session-id session.id}))))

(fn notify [msg level]
  (vim.schedule #(vim.notify msg level)))

;; async subprocess: k receives stdout on success; failures notify and
;; stop whatever chain called them
(fn run [argv k]
  (vim.system argv {:text true}
              (fn [obj]
                (vim.schedule #(if (= obj.code 0)
                                   (k (or obj.stdout ""))
                                   (notify (.. "codeboomer: `"
                                               (table.concat argv " ")
                                               "` failed (exit "
                                               (tostring obj.code) ")\n"
                                               (or obj.stderr ""))
                                           vim.log.levels.ERROR))))))

;; `gh pr view` → table with number, or notify
(fn gh-view [n k]
  (run [:gh :pr :view (tostring n) :--json "number"]
       (fn [out]
         (let [(ok pr) (pcall vim.json.decode out)]
           (if (and ok (= :table (type pr)) pr.number)
               (k pr)
               (notify (.. "codeboomer: `gh pr view " (tostring n)
                           "` gave nothing usable")
                       vim.log.levels.ERROR))))))

(fn choose-pr [prs k]
  (let [fzf (require :fzf-lua)
        by-display {}
        lines (icollect [_ p (ipairs prs)]
                (let [display (string.format "#%-5s %-55s %s"
                                             (tostring p.number) (or p.title "")
                                             (or p.headRefName ""))]
                  (tset by-display display p)
                  display))]
    (fzf.fzf_exec lines
                  {:prompt "Pick a PR> "
                   :actions {:default (fn [selected]
                                        (let [pr (. by-display (. selected 1))]
                                          (when pr (k pr))))}})))

;; unified-diff text → {rel-path [[start last] ...]} of the lines the
;; diff's + side touches: the +++ b/ path and the +(start,count) hunk
;; numbers. A hunk whose count is 0 (pure deletions) touches no lines
;; and is skipped; no ,count after the number means a single line
(fn parse-ranges [diff]
  (let [header-re "^%+%+%+ b/(.*)"
        hunk-re "^@@ %-%d+,?%d* %+(%d+),?(%d*) @@"
        out {}]
    (var file nil)
    (each [line (string.gmatch (or diff "") "[^\n]+")]
      (let [header (string.match line header-re)]
        (when (and header (not= header :/dev/null))
          (set file header))
        (let [(c d) (string.match line hunk-re)]
          (when (and file c)
            (let [start (tonumber c)
                  count (tonumber (if (or (not d) (= d "")) :1 d))]
              (when (> count 0)
                (let [bucket (or (. out file) [])]
                  (table.insert bucket [start (+ start count -1)])
                  (tset out file bucket))))))))
    out))

;; the PR's own diff, for the off-diff gate — exactly the diff GitHub
;; validates inline comments against. gh has no --unified, so hunks
;; carry their context lines along: harmless for the gate (a comment
;; on a context line is on-diff too). Best-effort — a failure leaves
;; ranges nil and the gate steps aside
(fn load-ranges [pr-number]
  (run [:gh :pr :diff (tostring pr-number) :--color=never]
       (fn [out] (set current.ranges (parse-ranges out)))))

;; open the PR review: find-or-create the current branch's session,
;; bind it to the PR, open the comments pane, then pull the PR's
;; inline comments down as threads and load the diff ranges. No
;; checkout happens — the code you annotate is the branch you are on
(fn open-pr [pr]
  (let [session-id (review.ensure-session)]
    (if (not session-id)
        (notify "codeboomer: not inside a git repository"
                vim.log.levels.ERROR)
        (do
          (review.set-session-pr session-id pr.number)
          (set current {:pr-number pr.number
                        :session-id session-id})
          (sidebar.open)
          (github.pull-comments pr.number session-id)
          (load-ranges pr.number)))))

;; :Codeboomer Review [n] — no number means pick from `gh pr list`;
;; choosing a PR IS opening its review
(set M.open
     (fn [?n]
       (if (not (git.repo-root))
           (notify "codeboomer: not inside a git repository"
                   vim.log.levels.ERROR)
           (if ?n
               (gh-view ?n open-pr)
               (run [:gh
                     :pr
                     :list
                     :--json
                     "number,title,headRefName"]
                    (fn [out]
                      (let [(ok prs) (pcall vim.json.decode out)]
                        (if (and ok (= :table (type prs)) (> (length prs) 0))
                            (choose-pr prs open-pr)
                            (notify "codeboomer: no open PRs (or `gh` unavailable)"
                                    vim.log.levels.WARN)))))))))

;; :Codeboomer PostReview — push the unposted annotations of this
;; branch's session to GitHub: replies to pulled threads via the
;; replies endpoint, fresh threads batched into one review per anchor
;; commit. The open PR review's diff gates the off-diff check when it
;; is the same session
(set M.post
     (fn []
       (let [sid (sidebar.session-id)
             session (when sid (review.session-by-id sid))]
         (github.post-threads
           {:session-id sid
            :ranges (when (and session current
                               (= session.id current.session-id))
                      current.ranges)}))))

;; :Codeboomer PullReview — refresh this branch's session with the
;; bound PR's current inline comments (idempotent by gh comment id)
(set M.pull (fn []
              (let [sid (sidebar.session-id)
                    session (when sid (review.session-by-id sid))]
                (if (and session session.pr_number)
                    (github.pull-comments session.pr_number sid)
                    (notify "codeboomer: this branch's session is not bound to a PR — :Codeboomer Review first"
                            vim.log.levels.WARN)))))

;; pure: unified-diff text → per-file ranges (unit-testable)
(set M.parse-ranges parse-ranges)

M
