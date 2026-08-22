;; [nfnl] varubrev/config.fnl
;; setup merges the user's opts into the config and applies the keymaps:
;;   (setup {:send "<leader>cs" :send_visual "<leader>cs" :pane "<leader>cp"})
;;
;; send_visual's rhs is a bare ":" (not <cmd>) so Vim auto-inserts the
;; '<,'> range; the Varubrev command's range handling uses it to prepend
;; the selection to the message. Keys use underscores so Fennel and Lua
;; callers spell them identically.
(global vim vim)

(local M {})

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
  (each [k [mode rhs desc] (pairs keymaps)]
    (when (. M.config k)
      (vim.keymap.set mode (. M.config k) rhs {: desc})))
  M.config)

M
