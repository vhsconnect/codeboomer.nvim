(local helpers (require :nvim-test.helpers))

(local uv vim.uv)
(local exec-lua helpers.exec_lua)
(local nvim-test-clear helpers.clear)

(local M helpers)

(local pj-root
       (assert (os.getenv :PJ_ROOT)
               "PJ_ROOT is unset, run tests through `make test`"))

(local scratch-root (.. pj-root :/scratch))
(local base-path (os.getenv :PATH))
(local timeout 2000)
(var scratch-seq 0)

(set M.fixtures {:files {:main :main.txt :readme :README.md}
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
                                  :user {:login :me}}
                 :remote "https://github.com/acme/widgets.git"
                 :pr {:number 42 :title :Widgets :headRefName :main}
                 :same-branch-pr {:number 43
                                  :title :Gadgets
                                  :headRefName :main}
                 :other-branch-pr {:number 44
                                   :title :Gizmos
                                   :headRefName :feature}
                 :pr-diff "diff --git a/main.txt b/main.txt
--- a/main.txt
+++ b/main.txt
@@ -40 +40 @@
-line 40
+line forty
"
                 :pr-reply {:id 556
                            :in_reply_to_id 555
                            :path :main.txt
                            :line 40
                            :body :follow-up
                            :user {:login :somebody}}})

;; stand-ins for the gh and tmux CLIs: every call is logged under
;; $CODEBOOMER_FAKES, gh answers from fixture files written by fake-gh
(local fake-gh-script "#!/usr/bin/env bash
dir=\"$CODEBOOMER_FAKES\"
printf '%s\\n' \"$*\" >> \"$dir/gh.log\"
f=
case \"$1 $2\" in
  'pr view') if [[ $3 =~ ^[0-9]+$ ]]; then f=\"$dir/gh/pr-view-$3.json\"; else f=\"$dir/gh/pr-view.json\"; fi ;;
  'pr list') f=\"$dir/gh/pr-list.json\" ;;
  'pr diff') f=\"$dir/gh/pr-diff-$3.txt\" ;;
  api\\ *)
    case \"$2\" in
      */replies) cat >> \"$dir/gh-stdin.log\"; echo '{\"id\": 9001}'; exit 0 ;;
      */reviews) cat >> \"$dir/gh-stdin.log\"; echo '{\"id\": 1}'; exit 0 ;;
      */comments) n=${2%/comments}; f=\"$dir/gh/pulls-${n##*/}-comments.jsonl\" ;;
    esac ;;
esac
if [ -n \"$f\" ] && [ -f \"$f\" ]; then cat \"$f\"; else echo \"fake gh: no fixture for: $*\" >&2; exit 1; fi
")

(local fake-tmux-script "#!/usr/bin/env bash
dir=\"$CODEBOOMER_FAKES\"
printf '%s\\n' \"$*\" >> \"$dir/tmux.log\"
case \"$1\" in
  list-panes) case \"$*\" in *session_name*) echo 'dev|$1|1|0|%1|claude||1|1|/tmp' ;; *) echo '%1' ;; esac ;;
  capture-pane) echo ready ;;
  load-buffer) cat >> \"$dir/tmux-paste.txt\" ;;
esac
")

(fn shell-quote [arg]
  (.. "'" (pick-values 1 (arg:gsub "'" "'\\''")) "'"))

(fn sh [...]
  (let [cmd (.. (table.concat (vim.tbl_map shell-quote [...]) " ") " 2>&1")
        handle (assert (io.popen cmd))
        out (handle:read :*a)]
    (when (not (handle:close))
      (error (: "command failed: %s\n%s" :format cmd out)))
    out))

;; nvim-test's neq is a saved assert.are_not.same chain; luassert
;; resets the chain's negation after its first use, so every later
;; call silently asserts sameness instead
(local luassert (require :luassert))
(fn M.neq [expected actual]
  (luassert.are_not.same expected actual))

(fn M.cleanup-scratch-root []
  (sh :rm :-rf scratch-root))

(fn write-file [path content]
  (with-open [file (assert (io.open path :w))]
    (file:write content)))

(fn install-fakes [bin]
  (each [name script (pairs {:gh fake-gh-script :tmux fake-tmux-script})]
    (write-file (.. bin "/" name) script)
    (sh :chmod :+x (.. bin "/" name))))

(fn M.clear []
  (set scratch-seq (+ scratch-seq 1))
  (set M.scratch (: "%s/test-%04d" :format scratch-root scratch-seq))
  (set M.repo (.. M.scratch :/repo))
  (set M.data-home (.. M.scratch :/data))
  (set M.fakes (.. M.scratch :/fakes))
  (let [bin (.. M.scratch :/bin)]
    (sh :mkdir :-p M.repo (.. M.data-home :/nvim) (.. M.fakes :/gh) bin)
    (install-fakes bin)
    (uv.os_setenv :PATH (.. bin ":" base-path)))
  (uv.os_setenv :XDG_DATA_HOME M.data-home)
  (uv.os_setenv :CODEBOOMER_FAKES M.fakes)
  (nvim-test-clear))

;; a fresh Nvim on the same scratch dir and database — what a user
;; sees after quitting and relaunching in the same checkout
(fn M.restart []
  (nvim-test-clear)
  (M.setup-codeboomer))

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
  (M.git :add ".")
  (M.git :commit :-q :-m :init)
  (M.git :remote :add :origin M.fixtures.remote))

(fn M.setup-codeboomer []
  (exec-lua (fn [plugin-root sqlite-root repo]
              (vim.opt.rtp:prepend plugin-root)
              (when sqlite-root
                (vim.opt.rtp:prepend sqlite-root))
              (vim.fn.chdir repo)
              (set _G.notifications [])
              (set vim.notify
                   (fn [msg level]
                     (table.insert _G.notifications {: msg : level})))
              ;; every fzf picker resolves at once to its first entry
              (set _G.fzf_prompts [])
              (tset package.preload :fzf-lua
                    (fn []
                      {:fzf_exec (fn [lines opts]
                                   (table.insert _G.fzf_prompts opts.prompt)
                                   (opts.actions.default [(. lines 1)]))})))
            pj-root (os.getenv :SQLITE_LUA_PATH) M.repo))

(fn M.notifications []
  (M.exec_lua "return _G.notifications"))

(fn M.fzf-prompts []
  (M.exec_lua "return _G.fzf_prompts"))

(fn M.fake-gh-json [name value]
  (exec-lua (fn [path value]
              (vim.fn.writefile [(vim.json.encode value)] path))
            (.. M.fakes :/gh/ name) value))

(fn M.fake-gh-jsonl [name items]
  (exec-lua (fn [path items]
              (vim.fn.writefile (vim.tbl_map vim.json.encode items) path))
            (.. M.fakes :/gh/ name) items))

(fn M.fake-gh-text [name text]
  (write-file (.. M.fakes :/gh/ name) text))

(fn M.fake-log [name]
  (case (io.open (.. M.fakes "/" name) :r)
    file (with-open [f file] (f:read :*a))
    _ ""))

(fn M.expectf [cond]
  (var duration 0)
  (var interval 1)
  (var done false)
  (while (and (not done) (< duration timeout))
    (let [(ok ret) (pcall cond)]
      (if (and ok (or (= ret nil) (= ret true)))
          (set done true)
          (do
            (set duration (+ duration interval))
            (M.sleep interval)
            (set interval (math.min (* interval 2) 50))))))
  (when (not done)
    (cond)))

(fn M.settle []
  (exec-lua #(vim.wait 300)))

(fn M.rest [win line]
  (exec-lua (fn [win line]
              (vim.api.nvim_win_set_cursor win [line 0])
              (vim.cmd "doautocmd CursorMoved")
              (vim.wait 300)) win line))

(fn M.find-pane [tab]
  (exec-lua (fn [tab]
              (accumulate [found nil _ w (ipairs (vim.api.nvim_tabpage_list_wins tab))
                           &until found]
                (when (: (vim.api.nvim_buf_get_name (vim.api.nvim_win_get_buf w))
                         :find "^codeboomer://review%-comments")
                  w))) tab))

(fn M.edit [path]
  (M.api.nvim_command (.. "edit " path)))

;; proxy whose fields call the matching function of (require name)
;; inside the child session, e.g. ((. (M.module :codeboomer.review) :promote) ...)
;; — results RPC cannot carry (a vim.system object, a function) come back as nil
(fn M.module [name]
  (M.create_callindex (fn [fn-name ...]
                        (exec-lua (fn [mod fname ...]
                                    (let [res (vim.F.pack_len ((. (require mod)
                                                                  fname) ...))]
                                      (for [i 1 res.n]
                                        (when (not (pcall vim.mpack.encode
                                                          (. res i)))
                                          (tset res i nil)))
                                      (vim.F.unpack_len res)))
                                  name fn-name ...))))

M
