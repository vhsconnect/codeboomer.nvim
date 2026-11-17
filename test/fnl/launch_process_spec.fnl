(local helpers (require :cb_helpers))

(local {: api : clear : eq : fixtures} helpers)
(local files fixtures.files)

(local codeboomer (helpers.module :codeboomer))

(helpers.env)

(local process-prompt "Pick a Process> ")

(fn settle []
  (helpers.exec_lua #(vim.wait 50)))

(fn notified? [text]
  (accumulate [found false _ n (ipairs (helpers.notifications)) &until found]
    (not= nil (n.msg:find text 1 true))))

;; entries run a stand-in for a configured long-lived process — the
;; harness, a repl, a watcher: it records where it was started and
;; streams what the pty delivers into a log
(fn stand-in [label]
  {: label
   :argv [:sh
          :-c
          (string.format "pwd > %s/%s-cwd.log; cat > %s/%s-in.log; sleep 5"
                         helpers.fakes label helpers.fakes label)
          :sh]})

(fn setup-processes [entries]
  (codeboomer.setup {:prompting {:launch_processes entries}}))

(fn launch []
  (api.nvim_command "Codeboomer LaunchProcess")
  (settle))

(fn buf-named [label]
  ;; buffer names come back absolute — match the trailing component
  (accumulate [found nil _ b (ipairs (helpers.exec_lua "return vim.api.nvim_list_bufs()"))
               &until found]
    (when (= label (string.match (api.nvim_buf_get_name b) "[^/]+$"))
      b)))

(fn picker-lines []
  ;; the labels behind the picker's display lines: the first word of
  ;; each line is the entry's label
  (vim.tbl_map #(string.match $1 "^(%S+)") (?. (helpers.fzf-calls) 1 :lines)))

(describe :LaunchProcess
          (fn []
            (before_each (fn []
                           (clear)
                           (helpers.setup-test-repo)
                           (helpers.setup-codeboomer)
                           (api.nvim_command "runtime plugin/codeboomer.lua")
                           (setup-processes [(stand-in :watcher)
                                             (stand-in :repl)])
                           (helpers.edit files.main)))
            (it "asks which process to launch"
                (fn []
                  (launch)
                  (eq [process-prompt] (helpers.fzf-prompts))))
            (it "offers the built-in processes when none are configured"
                (fn []
                  (setup-processes [])
                  ;; the built-ins alone are on offer — pi is queued to keep
                  ;; the stub from resolving to the first entry, which
                  ;; would start a real shell; pi is missing here, so the
                  ;; launch just fails
                  (helpers.fzf-pick process-prompt :pi)
                  (launch)
                  (eq [:terminal :pi :claude] (picker-lines))))
            (it "runs the picked process and tethers it as the pane"
                (fn []
                  (helpers.fzf-pick process-prompt :repl)
                  (launch)
                  (helpers.expectf #(assert (buf-named :repl)))
                  ;; a raw send reaches the pty without a pane pick
                  (api.nvim_command "1,2Codeboomer SendSelection")
                  (helpers.expectf #(let [in-log (helpers.fake-log :repl-in.log)]
                                      (assert (in-log:find "line 1" 1 true))))
                  (assert.is_false (vim.list_contains (helpers.fzf-prompts)
                                                      "Pick a Pane> "))))
            (it "reports a failed launch and tethers nothing"
                (fn []
                  (setup-processes [{:label :broken
                                     :argv [:codeboomer-missing-binary]}])
                  (helpers.fzf-pick process-prompt :broken)
                  (launch)
                  (helpers.expectf #(assert (notified? "LaunchProcess failed")))
                  (api.nvim_command "1,2Codeboomer SendSelection")
                  (helpers.expectf #(assert (vim.list_contains (helpers.fzf-prompts)
                                                               "Pick a Pane> ")))))
            (it "replaces a built-in entry when its label is reused"
                (fn []
                  (setup-processes [(stand-in :pi)])
                  (helpers.fzf-pick process-prompt :pi)
                  (launch)
                  ;; three entries, not four — the stand-in replaced the
                  ;; built-in pi instead of appending
                  (eq [:terminal :pi :claude] (picker-lines))
                  ;; and the replacement is what ran, on the work tree,
                  ;; in a buffer named after its label
                  (helpers.expectf #(let [cwd (vim.trim (helpers.fake-log :pi-cwd.log))]
                                      (assert (= cwd helpers.repo))))
                  (assert (buf-named :pi))))))
