;; [nfnl] varubrev/config.fnl
;; setup merges the user's opts into the config and applies the keymaps:
;;   (setup {:keybindings {:send "<leader>cs"
;;                         :send_visual "<leader>cs"
;;                         :pane "<leader>cp"}
;;           :prompting {:directives [{:label "..." :text "..."}]}})
;;
;; send_visual's rhs is a bare ":" (not <cmd>) so Vim auto-inserts the
;; '<,'> range; the Varubrev command's range handling uses it to prepend
;; the selection to the message. Keys use underscores so Fennel and Lua
;; callers spell them identically.
;;
;; The config is the runtime source of truth for prompting: setup folds
;; the built-in directive list and the default one-off command in, with
;; user-supplied values winning.
;;
;; prompting.one_off_command is a static argv list; the composed prompt is
;; appended as the final argument when the command runs.

(global vim vim)

(local M {})
(local directives (require :varubrev.directives))

(local keymaps {:send [:n
                       "<cmd>Varubrev SendKeys<cr>"
                       "varubrev: send message to pane"]
                :send_visual [:x
                              ":Varubrev SendKeys<cr>"
                              "varubrev: send selection to pane"]
                :pane [:n
                       "<cmd>Varubrev SetPane<cr>"
                       "varubrev: pick a tmux pane"]
                :send_with_directive [:n
                                      "<cmd>Varubrev SendWithDirective<cr>"
                                      "varubrev: Send Keys along with annotations"]
                :send_visualOO [:x
                                ":Varubrev SendKeysOO<cr>"
                                "varubrev: send one off action"]
                :annotate [:x
                           ":Varubrev Annotate<cr>"
                           "varubrev: annotate some text"]})

;; default one-off argv for SendKeysOO; the prompt is appended at runtime
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
