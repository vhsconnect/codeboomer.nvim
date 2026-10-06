;; :Codeboomer LaunchReviewer — pick an agent, pick what it reviews,
;; then spawn it in its own tmux window with a prompt pointing it at
;; the shim. The scopes:
;;   pr          — a PR picked through Review's own flow (binds the
;;                 branch session, pulls comments, loads the diff)
;;   uncommitted — staged, unstaged and untracked work on the branch
;;   commits     — a picked commit through HEAD
(global vim vim)

(local agent (require :codeboomer.agent))
(local git (require :codeboomer.git))
(local picker (require :codeboomer.picker))
(local review-agents (require :codeboomer.review-agents))
(local review-mode (require :codeboomer.review-mode))
(local tmux (require :codeboomer.tmux))

(local M {})

(local commit-pick-limit 100)

;; git's well-known empty tree — the diff base of a range that starts
;; at the root commit, which has no parent to diff against
(local empty-tree :4b825dc642cb6eb9a060e54bf8d69288fbee4904)

(fn notify [msg level]
  (vim.schedule #(vim.notify msg level)))

;; a single configured agent runs directly — the picker only appears
;; when there is an actual choice to make
(fn choose-agent [agents k]
  (if (= 1 (length agents))
      (k (. agents 1))
      (picker.choose "Review agent> " agents
                     #(string.format "%-16s %s" $1.label
                                     (table.concat $1.argv " "))
                     k)))

(fn commits [root]
  (let [out (git.run root :log :--first-parent
                     "--format=%h%x09%H%x09%s%x09%an, %ar" :-n
                     (tostring commit-pick-limit))]
    (icollect [line (string.gmatch (or out "") "[^\n]+")]
      (let [(short sha subject by) (string.match line
                                                 "^([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")]
        (when sha {: short : sha : subject : by})))))

(fn root-commit? [root sha]
  (= nil (git.run root :rev-parse :--verify :-q (.. sha "^"))))

(fn choose-commit [root k]
  (picker.choose "Review from commit (inclusive)> " (commits root)
                 #(string.format "%s  %s  (%s)" $1.short $1.subject $1.by)
                 #(k {:from $1.sha
                      :short $1.short
                      :root (root-commit? root $1.sha)})))

(fn dirty? [root]
  (not= "" (or (git.run root :status :--porcelain) "")))

(local scopes
       [{:kind :pr :label "GitHub PR — pick this branch's pull request"}
        {:kind :uncommitted
         :label "Uncommitted — staged, unstaged and untracked changes"}
        {:kind :commits :label "Commits — pick how far back to go"}])

(fn choose-scope [root k]
  (let [pick (fn [scope]
               (case scope.kind
                 :pr (review-mode.open nil #(k {:pr $1.number}))
                 :uncommitted (if (dirty? root) (k {:uncommitted true})
                                  (notify "codeboomer: nothing uncommitted to review"
                                          vim.log.levels.WARN))
                 :commits (choose-commit root k)))]
    (picker.choose "Review what> " scopes #$1.label pick)))

(fn scope-text [branch scope]
  (case scope
    {:pr n}
    (string.format "Review pull request #%d (`gh pr diff %d`), checked out here on branch %s."
                   n n branch)
    {:uncommitted true}
    (string.format "Review the uncommitted changes on branch %s — `git diff HEAD` plus the untracked files `git status` lists."
                   branch)
    {: short :root true}
    (string.format "Review every commit on branch %s from the root commit %s through HEAD (`git diff %s HEAD`)."
                   branch short empty-tree)
    {: short : from}
    (string.format "Review the commits on branch %s from %s (inclusive) through HEAD (`git log -p --first-parent %s~1..HEAD`)."
                   branch short from)))

(fn spawn [root branch agent-cmd scope on-pane]
  (let [prompt (agent.review-prompt (scope-text branch scope))
        argv (vim.list_extend (vim.list_slice agent-cmd.argv) [prompt])]
    (case (tmux.new-window root (.. "review:" branch) argv)
      (nil err) (notify (.. "codeboomer: LaunchReviewer failed: " err)
                        vim.log.levels.ERROR)
      pane-id (do
                (on-pane (or (tmux.pane-by-id pane-id)
                             {: pane-id :pane-mode ""}))
                (notify (string.format "codeboomer: %s reviewer launched in pane %s"
                                       agent-cmd.label pane-id)
                        vim.log.levels.INFO)))))

;; on-pane receives the new window's pane once the agent is running
(fn M.launch [on-pane]
  (let [root (git.work-root)
        branch (git.branch-name)
        agents (or (review-agents.list) [])]
    (if (= 0 (length agents))
        (notify "codeboomer: prompting.review_agents not set — call setup() first"
                vim.log.levels.ERROR)
        (not root)
        (notify "codeboomer: LaunchReviewer needs a repo file"
                vim.log.levels.ERROR)
        (not branch)
        (notify "codeboomer: LaunchReviewer needs a checked-out branch"
                vim.log.levels.ERROR)
        (choose-agent agents
                      (fn [agent-cmd]
                        (choose-scope root
                                      #(spawn root branch agent-cmd $1 on-pane)))))))

M
