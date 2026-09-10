(global vim vim)

(local M {})

(fn run [root ...]
  ;; run git in {root}, return trimmed stdout or nil on failure
  (let [out (vim.fn.system (vim.list_extend [:git :-C root] [...]))]
    (when (= vim.v.shell_error 0)
      (let [trimmed (out:gsub "\n+$" "")]
        trimmed))))

(fn M.repo-root []
  ;; e.g. "/home/vhs/Repos/codeboomer.nvim" — the dir containing .git
  (vim.fs.root 0 :.git))

;; every configured remote as {:name ... :url ...}, fetch lines only —
;; a repo can carry several (e.g. a self-hosted origin plus github)
(fn M.remotes []
  (let [root (M.repo-root)]
    (when root
      (let [out (run root :remote :-v)]
        (icollect [line (string.gmatch (or out "") "[^\n]+")]
          (let [(name url kind) (string.match line "(%S+)%s+(%S+)%s+%((%a+)%)")]
            (when (= kind "fetch") {: name : url})))))))

(fn M.branch-name []
  ;; "HEAD" means detached; nil means not in a repo
  (let [root (M.repo-root)]
    (when root (run root :rev-parse :--abbrev-ref :HEAD))))

(fn M.head-sha []
  ;; full sha of HEAD — the anchor_commit_sha for new threads
  (let [root (M.repo-root)]
    (when root (run root :rev-parse :HEAD))))

(fn M.user-email []
  ;; resolves repo-local config first, global as fallback
  (let [root (M.repo-root)]
    (when root (run root :config :user.email))))

(fn M.user-name []
  (let [root (M.repo-root)]
    (when root (run root :config :user.name))))

M
