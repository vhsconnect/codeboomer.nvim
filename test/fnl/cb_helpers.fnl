(local helpers (require :nvim-test.helpers))

(local uv vim.uv)
(local exec-lua helpers.exec_lua)
(local nvim-test-clear helpers.clear)

(local M helpers)

(local pj-root (assert (os.getenv :PJ_ROOT)
                       "PJ_ROOT is unset, run tests through `make test`"))

(local scratch-root (.. pj-root :/scratch))
(var scratch-seq 0)

(set M.fixtures
     {:files {:main :main.txt :readme :README.md}
      :file-line-count 100
      :pulled-item {:id 555
                    :path :main.txt
                    :line 40
                    :body "reviewer note"
                    :user {:login :somebody}
                    :commit_id :abc123}
      :come-home-item {:id 987
                       :path :README.md
                       :line 5
                       :body "posted wording"
                       :user {:login :me}}})

(fn shell-quote [arg]
  (.. "'" (pick-values 1 (arg:gsub "'" "'\\''")) "'"))

(fn sh [...]
  (let [cmd (.. (table.concat (vim.tbl_map shell-quote [...]) " ") " 2>&1")
        handle (assert (io.popen cmd))
        out (handle:read :*a)]
    (when (not (handle:close))
      (error (: "command failed: %s\n%s" :format cmd out)))
    out))

(fn M.cleanup-scratch-root []
  (sh :rm :-rf scratch-root))

(fn M.clear []
  (set scratch-seq (+ scratch-seq 1))
  (set M.scratch (: "%s/test-%04d" :format scratch-root scratch-seq))
  (set M.repo (.. M.scratch :/repo))
  (set M.data-home (.. M.scratch :/data))
  (sh :mkdir :-p M.repo (.. M.data-home :/nvim))
  (uv.os_setenv :XDG_DATA_HOME M.data-home)
  (nvim-test-clear))

(fn M.git [...]
  (sh :git :-C M.repo ...))

(fn M.write-to-file [path lines]
  (with-open [file (assert (io.open (.. M.repo "/" path) :w))]
    (file:write (.. (table.concat lines "\n") "\n"))))

(fn M.setup-test-repo []
  (M.git :init :-q :-b :main)
  (M.git :config :user.email "tester@example.com")
  (M.git :config :user.name :tester)
  (let [lines (fcollect [i 1 M.fixtures.file-line-count]
                (: "line %d" :format i))]
    (each [_ path (pairs M.fixtures.files)]
      (M.write-to-file path lines)))
  (M.git :add :.)
  (M.git :commit :-q :-m :init))

(fn M.setup-codeboomer []
  (exec-lua (fn [plugin-root sqlite-root repo]
              (vim.opt.rtp:prepend plugin-root)
              (when sqlite-root
                (vim.opt.rtp:prepend sqlite-root))
              (vim.fn.chdir repo))
            pj-root (os.getenv :SQLITE_LUA_PATH) M.repo))

(fn M.edit [path]
  (M.api.nvim_command (.. "edit " path)))

;; proxy whose fields call the matching function of (require name)
;; inside the child session, e.g. ((. (M.module :codeboomer.review) :promote) ...)
(fn M.module [name]
  (M.create_callindex (fn [fn-name ...]
                        (exec-lua (fn [mod fname ...]
                                    ((. (require mod) fname) ...))
                                  name fn-name ...))))

M
