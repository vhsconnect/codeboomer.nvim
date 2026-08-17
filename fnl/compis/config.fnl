;; [nfnl] compis/config.fnl
;; setup merges the user's opts into the config and applies the keymaps:
;;   (setup {:send "<leader>cs" :send_visual "<leader>cs" :pane "<leader>cp"})
;;
;; send_visual's rhs is a bare ":" (not <cmd>) so Vim auto-inserts the
;; '<,'> range; the Compis command's range handling uses it to prepend
;; the selection to the message. Keys use underscores so Fennel and Lua
;; callers spell them identically.
(global vim vim)

(local M {})

(local keymaps
  {:send        [:n "<cmd>Compis SendKeys<cr>" "compis: send message to pane"]
   :send_visual [:x ":Compis SendKeys<cr>" "compis: send selection to pane"]
   :pane        [:n "<cmd>Compis SetPane<cr>" "compis: pick a tmux pane"]})

(fn M.setup [opts]
  (set M.config (vim.tbl_deep_extend :force (or M.config {}) (or opts {})))
  (each [k [mode rhs desc] (pairs keymaps)]
    (when (. M.config k)
      (vim.keymap.set mode (. M.config k) rhs {:desc desc})))
  M.config)

M
