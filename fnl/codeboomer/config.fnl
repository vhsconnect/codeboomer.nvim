;; [nfnl] codeboomer/config.fnl
;; setup merges the user's opts into the config and applies the keymaps:
;;   (setup {:keybindings {:send_prompt "<leader>cs"
;;                         :send_selection "<leader>cr"
;;                         :pane "<leader>cp"}
;;           :prompting {:directives [{:label "..." :text "..."}]}})
;;
;; rhs values for commands that read a selection are a bare ":" (not
;; <cmd>) so Vim auto-inserts the '<,'> range in visual mode; in normal
;; mode the same rhs simply runs the command without a range. Keys use
;; underscores so Fennel and Lua callers spell them identically.
;;
;; The config is the runtime source of truth for prompting: setup folds
;; the built-in directive list and the default one-off command in, with
;; user-supplied values winning.
;;
;; prompting.one_off_command is a static argv list; the composed prompt is
;; appended as the final argument when the command runs.

(global vim vim)

(local M {})
(local directives (require :codeboomer.directives))

(local keymaps {:send_prompt [[:n :x]
                              ":Codeboomer SendPrompt<cr>"
                              "codeboomer: send prompt to pane"]
                :send_selection [:x
                                 ":Codeboomer SendSelection<cr>"
                                 "codeboomer: send selection to pane as-is"]
                :ask_one_off [[:n :x]
                              ":Codeboomer AskOneOff<cr>"
                              "codeboomer: run one-off query, reply shown here"]
                :flush_with_directive [:n
                                       "<cmd>Codeboomer FlushWithDirective<cr>"
                                       "codeboomer: flush annotations with directive to pane"]
                :pane [:n
                       "<cmd>Codeboomer SetPane<cr>"
                       "codeboomer: pick a tmux pane"]
                :annotate [:x
                           ":Codeboomer Annotate<cr>"
                           "codeboomer: annotate some text"]})

;; default one-off argv for AskOneOff; the prompt is appended at runtime
(local default-one-off-command [:claude-code
                                :--model
                                :haiku
                                :--output-format
                                :json
                                :--permission-mode
                                :acceptEdits
                                :-p])

(fn M.setup [opts]
  (set M.config (vim.tbl_deep_extend :force (or M.config {}) (or opts {})))
  ;; Fold the built-in prompting defaults into the config: the default
  ;; one-off argv is only set when the user didn't supply their own, and
  ;; directive entries override the built-ins by label / append new ones
  (let [prompting (or M.config.prompting {})]
    (when (not prompting.one_off_command)
      (set prompting.one_off_command (vim.list_slice default-one-off-command)))
    (let [effective (directives.defaults)
          index {}]
      (each [i d (ipairs effective)]
        (tset index d.label i))
      (each [_ d (ipairs (or (?. opts :prompting :directives) []))]
        (if (. index d.label)
            (tset effective (. index d.label) d)
            (table.insert effective d)))
      (set prompting.directives effective))
    (set M.config.prompting prompting))
  (each [k [mode rhs desc] (pairs keymaps)]
    (let [lhs (?. M.config :keybindings k)]
      (when lhs
        (vim.keymap.set mode lhs rhs {: desc}))))
  M.config)

M
