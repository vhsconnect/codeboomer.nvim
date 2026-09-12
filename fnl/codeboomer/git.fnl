(global vim vim)

(local M {})

(fn run [root ...]
  ;; run git in {root}, return trimmed stdout or nil on failure
  (let [out (vim.fn.system (vim.list_extend [:git :-C root] [...]))]
    (when (= vim.v.shell_error 0)
      (let [trimmed (out:gsub "\n+$" "")]
        trimmed))))

(fn buffer-root [?path]
  (vim.fs.root (or ?path 0) :.git))

(fn main-of [root]
  (let [gitfile (.. root :/.git)
        stat (vim.uv.fs_stat gitfile)]
    (if (and stat (= stat.type :file))
        (let [gitdir (string.match (or (?. (vim.fn.readfile gitfile) 1) "")
                                   "^gitdir:%s*(.+)")
              wt-meta (when gitdir (vim.fs.dirname gitdir))
              main-git (when (and wt-meta
                                  (= :worktrees (vim.fs.basename wt-meta)))
                         (vim.fs.dirname wt-meta))
              main (when main-git (vim.fs.dirname main-git))]
          (or main root))
        root)))

(fn M.repo-root [?path]
  ;; e.g. "/home/vhs/Repos/codeboomer.nvim" — the dir containing .git,
  ;; canonicalized to the main checkout when inside a linked worktree
  ;; (sessions and repos keep one identity across checkouts). ?path
  ;; seeds the upward search; defaults to the current buffer so
  ;; headless callers (the agent shim) can pass a file instead
  (let [root (buffer-root ?path)]
    (when root (main-of root))))

;; absolute path → repo-relative; the original when {path} is not
;; inside a work tree (or the buffer has no name). Threads store
;; relative paths so they survive different checkouts — worktrees,
;; other machines — and match `gh` payload paths as-is. Relative to
;; the IMMEDIATE work tree, so worktree buffers resolve like main-
;; checkout ones
(fn M.rel-path [?path]
  (let [p (or ?path (vim.api.nvim_buf_get_name 0))
        root (buffer-root p)]
    (if (and root (= 1 (p:find (.. root "/") 1 true)))
        (p:sub (+ 2 (length root)))
        p)))

(fn M.remotes []
  (let [root (M.repo-root)]
    (when root
      (let [out (run root :remote :-v)]
        (icollect [line (string.gmatch (or out "") "[^\n]+")]
          (let [(name url kind) (string.match line "(%S+)%s+(%S+)%s+%((%a+)%)")]
            (when (= kind :fetch) {: name : url})))))))

(fn M.branch-name []
  (let [root (M.repo-root)]
    (when root (run root :rev-parse :--abbrev-ref :HEAD))))

(fn M.head-sha [?path]
  (let [root (buffer-root ?path)]
    (when root (run root :rev-parse :HEAD))))

(fn M.user-email []
  (let [root (M.repo-root)]
    (when root (run root :config :user.email))))

(fn M.user-name []
  (let [root (M.repo-root)]
    (when root (run root :config :user.name))))

M
