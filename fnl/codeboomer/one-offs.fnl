(global vim vim)

(local M {})

;; built-in one-off command entries for AskOneOff; each entry pairs a
;; label (shown in the fzf picker and the input title) with a static argv
;; list the composed prompt is appended to as the final argument at
;; runtime. Entries may carry an optional timeout (milliseconds).
(local default-one-offs [{:label "claude-code (haiku)"
                          :argv [:claude-code
                                 :--model
                                 :haiku
                                 :--output-format
                                 :json
                                 :--permission-mode
                                 :acceptEdits
                                 :-p]}])

(fn M.defaults []
  "Return a fresh copy of the built-in one-off commands"
  (icollect [_ c (ipairs default-one-offs)]
    {:label c.label :argv (vim.list_slice c.argv)}))

(fn M.list []
  "Return the effective one-off commands from the config"
  (?. (require :codeboomer.config) :config :prompting :one_off_commands))

M
