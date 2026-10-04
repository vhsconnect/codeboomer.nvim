;; [nfnl] codeboomer/review-mode.fnl
;; The PR half of codeboomer's review flow. There is no worktree and
;; no snapshot to set up: you review the PR's branch as you have it
;; checked out — committed or dirty — by annotating it where it
;; stands.
;; :Codeboomer Review picks a PR whose head is the checked-out branch
;; and binds this branch's session to it, once: the PR's inline
;; comments come down as threads and the PR's diff is loaded for the
;; off-diff gate; the comments pane follows the cursor from there.
;; Promote (the pane's p key) creates the shipping half in the PR
;; session; PostReview pushes it up — see github.fnl
(global vim vim)

(local git (require :codeboomer.git))
(local review (require :codeboomer.review))
(local sidebar (require :codeboomer.sidebar))
(local github (require :codeboomer.github))

(local M {})

;; pr-number → the PR's own diff (gh pr diff) as {rel-path [[start
;; last] ...]}, what the off-diff gate reads; false when gh could not
;; produce it, in which case the gate steps aside and GitHub's own
;; rejection surfaces at post time. Keyed by the PR, not the open
;; review, so a restart only costs one reload
(local diff-ranges {})

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
  (run [:gh :pr :view (tostring n) :--json "number,headRefName,headRefOid"]
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
;; on a context line is on-diff too)
(fn diff-argv [pr-number]
  [:gh :pr :diff (tostring pr-number) :--color=never])

;; Review refreshes the cache in the background
(fn load-ranges [pr-number]
  (vim.system (diff-argv pr-number) {:text true}
              (fn [obj]
                (vim.schedule #(tset diff-ranges pr-number
                                     (if (= obj.code 0)
                                         (parse-ranges obj.stdout)
                                         false))))))

;; a gate that needs the diff before Review loaded it this run (after
;; a restart) fetches it on the spot — p and PostReview must answer now
(fn ranges-for [pr-number]
  (when (= nil (. diff-ranges pr-number))
    (let [obj (: (vim.system (diff-argv pr-number) {:text true}) :wait 10000)]
      (tset diff-ranges pr-number (if (= obj.code 0) (parse-ranges obj.stdout)
                                      false))))
  (or (. diff-ranges pr-number) nil))

;; what the pane's p key promotes against, for the branch session row
;; the sidebar resolved: PR-bound sessions promote, carrying their
;; PR's diff for the off-diff gate; nil (unbound, or soft-deleted and
;; so resolved as gone) refuses p
(fn M.promote-context [session]
  (when (and session session.pr_number)
    {:session-id session.id :head-ranges (ranges-for session.pr_number)}))

;; the checked-out branch counts as the PR's when it is named after
;; the PR's head, tracks it (gh pr checkout -b, fork PRs), tracks the
;; PR's pull ref, or sits on the PR's head commit (a plain
;; `git fetch origin pull/N/head:name`)
(fn pr-branch? [branch pr]
  (let [merge (git.merge-ref branch)]
    (or (= branch pr.headRefName)
        (= merge (.. :refs/heads/ (or pr.headRefName "")))
        (= merge (string.format "refs/pull/%d/head" pr.number))
        (and (not= nil pr.headRefOid) (= (git.head-sha) pr.headRefOid)))))

;; open the PR review: the PR must be the checked-out branch's and the
;; branch's session may be bound to it only — then find-or-create the
;; session, bind it, open the comments pane, pull the PR's inline
;; comments down as threads and load the diff ranges. No checkout
;; happens — the code you annotate is the branch you are on
(fn open-pr [pr]
  (let [branch (git.branch-name)
        bound (?. (review.session-for) :pr_number)]
    (if (not branch)
        (notify (string.format "codeboomer: check out PR #%d's branch `%s` first — sessions are tied to branches, a detached HEAD has none"
                               pr.number (or pr.headRefName "?"))
                vim.log.levels.ERROR)
        (not (pr-branch? branch pr))
        (notify (string.format "codeboomer: PR #%d is for branch `%s`, but `%s` is checked out and neither tracks it nor sits on its head commit — check out `%s` first"
                               pr.number (or pr.headRefName "?") branch
                               (or pr.headRefName "?"))
                vim.log.levels.ERROR)
        (and bound (not= bound pr.number))
        (notify (string.format "codeboomer: this branch's session is bound to PR #%d — :Codeboomer ResetSession first to review PR #%d"
                               bound pr.number)
                vim.log.levels.ERROR)
        (let [session-id (review.ensure-session)]
          (review.set-session-pr session-id pr.number)
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
                     "number,title,headRefName,headRefOid"]
                    (fn [out]
                      (let [(ok prs) (pcall vim.json.decode out)]
                        (if (and ok (= :table (type prs)) (> (length prs) 0))
                            (choose-pr prs open-pr)
                            (notify "codeboomer: no open PRs (or `gh` unavailable)"
                                    vim.log.levels.WARN)))))))))

;; :Codeboomer PostReview — push the unposted annotations of this
;; branch's session to GitHub: replies to pulled threads via the
;; replies endpoint, fresh threads batched into one review per anchor
;; commit. The bound PR's diff gates the off-diff check
(set M.post
     (fn []
       (let [sid (sidebar.session-id)
             session (when sid (review.session-by-id sid))]
         (github.post-threads {:session-id sid
                               :ranges (when (?. session :pr_number)
                                         (ranges-for session.pr_number))}))))

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
