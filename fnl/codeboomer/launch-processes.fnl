(global vim vim)

(local M {})

;; the long-lived processes LaunchProcess can start: the coding agents
;; called straight off PATH, plus a plain terminal on the user's shell —
;; each runs on the work tree in a terminal buffer that becomes the pane
(local default-launch-processes
       [{:label :terminal :argv [vim.o.shell]}
        {:label :pi :argv [:pi]}
        {:label :claude :argv [:claude]}])

(fn M.defaults []
  "Return a fresh copy of the built-in launch processes"
  (icollect [_ p (ipairs default-launch-processes)]
    {:label p.label :argv (vim.list_slice p.argv)}))

(fn M.list []
  "Return the effective launch processes from the config"
  (?. (require :codeboomer.config) :config :prompting :launch_processes))

M
