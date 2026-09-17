;; [nfnl] codeboomer/review-mode.fnl
;; Snapshot review of a pull request: the PR head is fetched and
;; materialized as a detached git worktree, and a review tab opens
;; with the code on the left — read-only, changed ranges tinted — and
;; the sidebar's comments pane on the right (sticky in this mode: it
;; follows the cursor between threads but never collapses). Threads
;; anchor to the worktree's HEAD, i.e. the fetched PR head, and
;; because the checkout cannot be edited, line numbers cannot drift
;; by construction. This is review only — nothing is posted anywhere
;; (posting is a later phase).
(global vim vim)

(local git (require :codeboomer.git))
(local review (require :codeboomer.review))
(local sidebar (require :codeboomer.sidebar))
(local github (require :codeboomer.github))

(local M {})

(local range-ns (vim.api.nvim_create_namespace :codeboomer-review-ranges))
;; the tint for lines the diff touches, per side: DiffAdd reads as
;; "new in this change" on the head, DiffDelete as "gone from it" on
;; the base — both in every theme
(fn range-hl [side]
  (if (= side :old) :DiffDelete :DiffAdd))
;; the remote PR refs are fetched from — origin is the 99% case
(local remote :origin)

;; the open review: {:pr-number :head-sha :base-sha :branch :worktree
;; :session-id :side :head-ranges :base-ranges :ranges} — nil when none
;; is open. side is :new (head, the default) or :old (base, what
;; ReviewSide flips to); ranges follows the side being shown
(var current nil)

(fn notify [msg level]
  (vim.schedule #(vim.notify msg level)))

;; async subprocess: k receives stdout on success; failures notify and
;; stop whatever chain called them
(fn run [argv k]
  (vim.system argv {:text true}
              (fn [obj]
                (vim.schedule
                  #(if (= obj.code 0)
                       (k (or obj.stdout ""))
                       (notify (.. "codeboomer: `" (table.concat argv " ")
                                   "` failed (exit " (tostring obj.code) ")\n"
                                   (or obj.stderr ""))
                               vim.log.levels.ERROR))))))

(fn under-worktree [path]
  (let [p (or path "")]
    (and current (= 1 (p:find (.. current.worktree "/") 1 true)))))

;; worktrees live outside every repo, under nvim's data dir — one per
;; repo basename + id ("pr42", "worktree"), disposable via
;; `git worktree remove`
(fn worktree-path [id]
  (let [root (git.repo-root)]
    (when root
      (.. (vim.fn.stdpath :data) :/codeboomer-review/
          (vim.fs.basename root) :- id))))

;; reuse an existing worktree by hard-resetting it onto the sha — the
;; object store is shared with the main checkout, so no re-fetch is
;; needed; otherwise prune stale registrations (a worktree dir deleted
;; behind git's back stays registered until pruned) and create it
;; detached at the sha
(fn ensure-worktree [path sha k]
  (if (vim.uv.fs_stat path)
      (run [:git :-C path :checkout :--detach sha]
           (fn [_]
             (run [:git :-C path :reset :--hard sha]
                  (fn [_]
                    (run [:git :-C path :clean :-fd]
                         (fn [_] (k)))))))
      (do
        (vim.fn.mkdir (or (vim.fs.dirname path) ".") :p)
        (run [:git :worktree :prune]
             (fn [_]
               (run [:git :worktree :add :--detach path sha]
                    (fn [_] (k))))))))

;; `git diff --unified=0 base..head` → {rel-path [[start last] ...]}
;; of one side's ranges the diff touches. ?side :head (the default)
;; reads the +++ b/ path and the +(start,count) hunk numbers — the new
;; code; :base reads --- a/ and -(start,count) — the old code the diff
;; removed or rewrote. A hunk whose count is 0 on the side being read
;; (pure deletions head-side, pure additions base-side) touches no
;; lines there and is skipped
(fn parse-ranges [diff ?side]
  (let [base-side (= ?side :base)
        header-re (if base-side "^--- a/(.*)" "^%+%+%+ b/(.*)")
        hunk-re (if base-side
                    "^@@ %-(%d+),?(%d*) %+%d+,?%d* @@"
                    "^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
        out {}]
    (var file nil)
    (each [line (string.gmatch (or diff "") "[^\n]+")]
      (let [header (string.match line header-re)]
        (when (and header (not= header "/dev/null"))
          (set file header))
        (let [(c d) (string.match line hunk-re)]
          (when (and file c)
            ;; no ,count after the number means a single line; a count
            ;; of 0 means the hunk touches nothing on this side
            (let [start (tonumber c)
                  count (tonumber (if (or (not d) (= d "")) "1" d))]
              (when (> count 0)
                (let [bucket (or (. out file) [])]
                  (table.insert bucket [start (+ start count -1)])
                  (tset out file bucket))))))))
    out))

;; tint every changed line of {path} with the shown side's tint —
;; cleared and re-placed per buffer enter so switching files or
;; sides just works
(fn place-ranges [bufnr path]
  (when (vim.api.nvim_buf_is_valid bufnr)
    (let [line-count (vim.api.nvim_buf_line_count bufnr)
          hl (range-hl current.side)]
      (vim.api.nvim_buf_clear_namespace bufnr range-ns 0 -1)
      (each [_ [start last] (ipairs (or (. current.ranges path) []))]
        (for [ln start (math.min last line-count)]
          (vim.api.nvim_buf_set_extmark bufnr range-ns (- ln 1) 0
                                        {:line_hl_group hl}))))))

;; the read-only half of the mode: any buffer entered under the review
;; worktree becomes unmodifiable and gets its changed ranges tinted
(fn configure-code-buffer [bufnr]
  (when (and current (vim.api.nvim_buf_is_valid bufnr))
    (let [path (vim.api.nvim_buf_get_name bufnr)]
      (when (under-worktree path)
        (let [bo (. vim.bo bufnr)
              rel (path:sub (+ 2 (length current.worktree)))]
          ;; no drift to manage: the snapshot simply cannot be edited
          (set bo.modifiable false)
          (set bo.readonly true)
          ;; which side this buffer shows — Annotate and the sidebar's
          ;; marks read the stamp back; re-placing the marks HERE (not
          ;; only in the sidebar's own BufEnter) because this hook runs
          ;; after it and the stamp decides what belongs
          (set (. vim.b bufnr :codeboomer_review_side) current.side)
          (sidebar.mark-buffer bufnr)
          (place-ranges bufnr rel))))))

;; the side swap rewrites every file under the worktree on disk:
;; buffers still on screen are re-read (`:e!` re-fires BufEnter, so
;; re-tinting and the side stamp come along for free) with each
;; window's cursor and scroll saved and restored around the reload,
;; so the swap causes no jump (positions clamp to the new content's
;; length) — and buffers of files the other side does not have —
;; PR-added files on the old side, deleted ones on the new — are
;; wiped with a note instead of lingering as ghosts
(fn reload-worktree-buffers []
  (each [_ bufnr (ipairs (vim.api.nvim_list_bufs))]
    (when (and (vim.api.nvim_buf_is_valid bufnr)
               (vim.api.nvim_buf_is_loaded bufnr)
               (under-worktree (vim.api.nvim_buf_get_name bufnr)))
      (let [name (vim.api.nvim_buf_get_name bufnr)
            wins (vim.fn.win_findbuf bufnr)
            gone (not (vim.uv.fs_stat name))]
        (if (and (not gone) (> (length wins) 0))
            (each [_ w (ipairs wins)]
              (let [view (vim.api.nvim_win_call w vim.fn.winsaveview)]
                (vim.api.nvim_win_call w #(vim.cmd "silent! edit!"))
                (vim.api.nvim_win_call w #(vim.fn.winrestview view))))
            (do
              (when gone
                (notify (.. "codeboomer: " (vim.fs.basename name)
                            " does not exist on the "
                            (if (= current.side :old) "old" "new") " side")
                        vim.log.levels.INFO))
              (vim.api.nvim_buf_delete bufnr {:force true})))))))

;; `gh pr view` → table with number/headRefName/baseRefName, or notify
(fn gh-view [n k]
  (run [:gh :pr :view (tostring n) :--json "number,headRefName,baseRefName"]
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
                                             (tostring p.number)
                                             (or p.title "")
                                             (or p.headRefName ""))]
                  (tset by-display display p)
                  display))]
    (fzf.fzf_exec lines
                  {:prompt "Pick a PR> "
                   :actions {:default (fn [selected]
                                        (let [pr (. by-display (. selected 1))]
                                          (when pr (k pr))))}})))

;; the remote PR refs are fetched from: origin when origin points at
;; github.com, else the first remote that does — repos mirrored to a
;; self-hosted origin still fetch through their github remote (GitHub
;; advertises refs/pull/*/head on every GitHub remote)
(fn pick-fetch-remote []
  (let [remotes (or (git.remotes) [])]
    (var pick nil)
    (each [_ r (ipairs remotes) &until pick]
      (when (and (= r.name "origin")
                 (string.find (or r.url "") "github.com" 1 true))
        (set pick r.name)))
    (each [_ r (ipairs remotes) &until pick]
      (when (string.find (or r.url "") "github.com" 1 true)
        (set pick r.name)))
    pick))

;; pull the PR head and the base branch, then review the three-dot
;; shape GitHub diffs: merge-base..head. Once the review is open, the
;; PR's existing inline comments come down as threads (idempotent).
;; Fetched into codeboomer's own named refs rather than read back off
;; FETCH_HEAD: that file is shared repo-wide, and any other fetch
;; racing in the same window (an editor's auto-fetch, another
;; codeboomer review, a plain `git fetch` in a terminal) can clobber it
;; before the rev-parse runs, handing back the wrong commit
(fn open-pr [pr]
  (let [fetch-remote (pick-fetch-remote)
        head-ref (.. "refs/codeboomer/pr-" pr.number "-head")
        base-ref (.. "refs/codeboomer/pr-" pr.number "-base")]
    (if (not fetch-remote)
        (notify "codeboomer: no remote to fetch the PR from"
                vim.log.levels.ERROR)
        (run [:git :fetch fetch-remote
              (string.format "+pull/%d/head:%s" pr.number head-ref)]
             (fn [_]
               (run [:git :fetch fetch-remote
                     (string.format "+%s:%s" pr.baseRefName base-ref)]
                    (fn [_]
                      (run [:git :rev-parse head-ref]
                           (fn [head]
                             (run [:git :rev-parse base-ref]
                                  (fn [base]
                                    (run [:git :merge-base (vim.trim base)
                                          (vim.trim head)]
                                         (fn [mb]
                                           (M.setup-review
                                             {:pr-number pr.number
                                              :head-sha (vim.trim head)
                                              :base-sha (vim.trim mb)
                                              :branch pr.headRefName}
                                             #(github.pull-comments
                                                pr.number)))))))))))))))

;; stage the working tree (untracked included, ignored excluded) into
;; a throwaway index and read back its tree sha — nothing touches the
;; real index, HEAD, or any ref
(fn stage-worktree [root k]
  (let [index (.. root "/.git/codeboomer-snapshot-index")
        cmd (string.format "rm -f '%s' && GIT_INDEX_FILE='%s' git -C '%s' add -A && GIT_INDEX_FILE='%s' git -C '%s' write-tree"
                           index index root index root)]
    (run [:sh :-c cmd]
         (fn [out] (k (vim.trim out))))))

;; a dangling commit of the working tree with HEAD as parent — the sha
;; reviews exactly like a PR head, and because nothing references it,
;; git forgets it at the next gc once the review is over
(fn snapshot-commit [root head k]
  (stage-worktree root
    (fn [tree]
      (if (or (not tree) (= "" tree))
          (notify "codeboomer: could not snapshot the working tree"
                  vim.log.levels.ERROR)
          (run [:git :-C root :commit-tree tree :-p head
                :-m "codeboomer-snapshot"]
               (fn [out] (k (vim.trim out))))))))

;; compute the changed ranges of both sides once for the whole diff;
;; buffers look themselves up on enter. current.ranges follows the
;; side being shown; PostReview's off-diff gate always reads the
;; head's
(fn load-ranges [k]
  (run [:git :-C current.worktree
        :diff :--unified=0
        (.. current.base-sha ".." current.head-sha)]
       (fn [out]
         (set current.head-ranges (parse-ranges out))
         (set current.base-ranges (parse-ranges out :base))
         (set current.ranges (if (= current.side :old)
                                 current.base-ranges
                                 current.head-ranges))
         (k))))

;; the tab: code window (empty until a file is picked) + the sticky
;; comments pane; the file picker is the entry into the diff
(fn open-review-tab []
  (vim.cmd :tabnew)
  (sidebar.open-sticky)
  ;; pick where to start; headless runs (tests) cannot open fzf
  (let [(ok) (pcall M.files)]
    (when (not ok)
      (notify "codeboomer: review open — :Codeboomer ReviewFiles to jump"
              vim.log.levels.INFO))))

;; fzf over the side being shown's changed files; picking edits the
;; worktree copy in the code window
(set M.files
     (fn []
       (if (not current)
           (notify "codeboomer: no review open — :Codeboomer Review first"
                   vim.log.levels.WARN)
           (let [paths (vim.tbl_keys current.ranges)]
             (if (= 0 (length paths))
                 (notify "codeboomer: no changed files in this review"
                         vim.log.levels.WARN)
                 (do
                   (table.sort paths)
                   (let [fzf (require :fzf-lua)]
                     (fzf.fzf_exec paths
                                   {:prompt (string.format
                                              "Pick a Changed File (%s side)> "
                                              (if (= current.side :old)
                                                "old" "new"))
                                    :actions
                                    {:default
                                     (fn [selected]
                                       (let [path (. selected 1)]
                                         (vim.cmd {:cmd :edit
                                                   :args [(.. current.worktree "/"
                                                              path)]})))}}))))))))

;; :Codeboomer ReviewSide / <leader>ct — flip the open review between
;; the two ends of its diff: the worktree checks out the other sha and
;; the tints re-target, so the code the diff REMOVED becomes readable
;; (tinted) on the old side instead of invisible. Threads and
;; annotations stay anchored to the new side — Annotate refuses on
;; the old one and the gutter bars hide — the old side is for reading
(set M.toggle-side
     (fn []
       (if (not current)
           (notify "codeboomer: no review open — :Codeboomer Review first"
                   vim.log.levels.WARN)
           (let [side (if (= current.side :old) :new :old)
                 sha (if (= side :old) current.base-sha current.head-sha)]
             (run [:git :-C current.worktree :checkout :--detach sha]
                  (fn [_]
                    (set current.side side)
                    (set current.ranges (if (= side :old)
                                            current.base-ranges
                                            current.head-ranges))
                    (reload-worktree-buffers)
                    ;; thread numbers are new-side ones — the reload
                    ;; re-places the marks (nowhere on the old side)
                    (sidebar.reload-threads)
                    (notify (.. "codeboomer: showing the "
                                (if (= side :old) "old" "new") " code")
                            vim.log.levels.INFO)))))))

;; given resolved shas: worktree the head, find-or-create the session,
;; choose it, open the review tab, then run ?done. opts: {:pr-number
;; :worktree-id :head-sha :base-sha :branch} — the gh-free seam tests
;; use directly. PR reviews reuse their session (keyed by pr-number);
;; others always start a fresh conversation
(set M.setup-review
     (fn [opts ?done]
       (let [path (worktree-path (or opts.worktree-id
                                     (.. "pr" (or opts.pr-number ""))))]
         (if (not path)
             (notify "codeboomer: not inside a git repository"
                     vim.log.levels.ERROR)
             (ensure-worktree path opts.head-sha
               (fn []
                 (let [copts {:pr-number opts.pr-number
                              :head-sha opts.head-sha
                              :base-sha opts.base-sha
                              :branch opts.branch}
                       session (if opts.pr-number
                                   (or (review.session-for-pr opts.pr-number)
                                       (review.create-session copts))
                                   (review.create-session copts))]
                   (set current {:pr-number opts.pr-number
                                 :head-sha opts.head-sha
                                 :base-sha opts.base-sha
                                 :branch opts.branch
                                 :worktree path
                                 :session-id session
                                 ;; a review always opens on the new
                                 ;; side; ReviewSide flips it
                                 :side :new
                                 :head-ranges {}
                                 :base-ranges {}
                                 :ranges {}})
                   ;; choose it — the sidebar reloads its thread map
                   (review.set-session session)
                   (load-ranges (fn []
                                  (open-review-tab)
                                  (when ?done (?done)))))))))))

;; :Codeboomer Review [n] — no number means pick from `gh pr list`;
;; choosing a PR IS opening its review
(set M.open
     (fn [?n]
       (if (not (git.repo-root))
           (notify "codeboomer: not inside a git repository"
                   vim.log.levels.ERROR)
           (if ?n
               (gh-view ?n open-pr)
               (run [:gh :pr :list :--json "number,title,headRefName,baseRefName"]
                    (fn [out]
                      (let [(ok prs) (pcall vim.json.decode out)]
                        (if (and ok (= :table (type prs))
                                 (> (length prs) 0))
                            (choose-pr prs open-pr)
                            (notify "codeboomer: no open PRs (or `gh` unavailable)"
                                    vim.log.levels.WARN)))))))))

;; :Codeboomer ReviewWorktree — review the uncommitted working tree
;; against HEAD: snapshot it into a dangling commit (non-destructive:
;; no ref moves, `git status` untouched) and open the standard review
;; mode on it. The read-only bridge for reviewing agent-made changes
;; before they are committed
(set M.review-worktree
     (fn []
       (let [root (git.repo-root)
             head (git.head-sha)]
         (if (not (and root head))
             (notify "codeboomer: not inside a git repository with commits"
                     vim.log.levels.ERROR)
             (snapshot-commit root head
               (fn [sha]
                 (M.setup-review {:worktree-id :worktree
                                  :head-sha sha
                                  :base-sha head
                                  :branch (git.branch-name)})))))))

;; :Codeboomer PostReview — push my unposted annotations of the
;; chosen PR session to GitHub: replies to pulled threads via the
;; replies endpoint, fresh threads batched into one review per anchor
;; commit. The open review's HEAD-side ranges gate the off-diff check
;; whichever side is being viewed
(set M.post
     (fn []
       (github.post-threads {:ranges (when current current.head-ranges)})))

;; :Codeboomer PullReview — refresh the chosen PR session with the
;; PR's current inline comments (idempotent by gh comment id)
(set M.pull
     (fn []
       (let [sid (review.current-session-id)
             session (when sid (review.session-by-id sid))]
         (if (and session session.pr_number)
             (github.pull-comments session.pr_number)
             (notify "codeboomer: the chosen session is not a PR review"
                     vim.log.levels.WARN)))))

;; the open review's state, for callers and tests
(set M.info (fn [] current))

;; pure: diff text → per-file ranges of one diff side (unit-testable)
(set M.parse-ranges parse-ranges)

;; the remote PR refs would be fetched from, for callers and tests
(set M.fetch-remote pick-fetch-remote)

(vim.api.nvim_create_augroup :codeboomer-review-mode {:clear true})
(vim.api.nvim_create_autocmd :BufEnter
                             {:group :codeboomer-review-mode
                              :callback (fn []
                                          (when current
                                            (configure-code-buffer 0)))})

M
