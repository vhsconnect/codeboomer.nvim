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
;; The config is the runtime source of truth for directives: setup always
;; folds the built-in ones in, with user-supplied entries overriding by
;; label.

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

(fn M.setup [opts]
  (set M.config (vim.tbl_deep_extend :force (or M.config {}) (or opts {})))
  ;; Always fold the built-in directives into the config: a user entry
  ;; with a duplicate label overrides the built-in in place, and entries
  ;; with new labels are appended after them
  (let [effective (directives.defaults)
        index {}]
    (each [i d (ipairs effective)]
      (tset index d.label i))
    (each [_ d (ipairs (or (?. opts :prompting :directives) []))]
      (if (. index d.label)
          (tset effective (. index d.label) d)
          (table.insert effective d)))
    (tset M.config :prompting (vim.tbl_deep_extend :force
                                (or M.config.prompting {})
                                {:directives effective})))
  (each [k [mode rhs desc] (pairs keymaps)]
    (let [lhs (?. M.config :keybindings k)]
      (when lhs
        (vim.keymap.set mode lhs rhs {: desc}))))
  M.config)

M
