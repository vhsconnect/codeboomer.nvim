;; dev/reload.fnl — the Conjure hot-reload loop for this plugin.
;;
;; Conjure's fennel client evaluates in-process, inside the same
;; Neovim Lua instance the plugin runs in: an evaluated form can purge
;; package.loaded and re-require the plugin, reloading it without
;; restarting the session. This file lives outside fnl/ on purpose —
;; nfnl's source-file-patterns (.nfnl.fnl) only build fnl/**, so
;; nothing here is compiled into lua/ or ships with the plugin; it
;; only ever runs under Conjure.
;;
;; The loop:
;;   1. edit fnl/codeboomer/*.fnl (agent or by hand)
;;   2. :NfnlCompileAllFiles — compiles from disk, so stale open
;;      buffers don't matter
;;   3. evaluate the whole file once (Conjure's eval-buffer) — the
;;      trailing (reload) runs in the same chunk as the definitions;
;;      from then on re-evaluating just that (reload) form is enough
;;
;; After a reload the chosen tmux pane is forgotten (re-pick with
;; <leader>cp), and an open comments pane should be closed first: the
;; fresh sidebar module starts with no window reference and would open
;; a duplicate.

(global vim vim)

;; the dev opts — mirroring ./test-codeboomer. Evaluated forms carry
;; these into setup(); set to nil to instead re-use whatever the live
;; config module last merged (the snapshot taken in reload)
(local dev-opts {:debug false
                 :keybindings {:send_prompt :<leader>cs
                               :send_last_prompt :<leader>cl
                               :send_selection :<leader>cr
                               :ask_one_off :<leader>cc
                               :flush_with_directive :<leader>cd
                               :pane :<leader>cp
                               :reset_session :<leader>cS
                               :review :<leader>cR
                               :post_review :<leader>cP
                               :pull_review :<leader>cL
                               :annotate :<leader>ca}})

;; re-apply opts to the live modules — no purge, no recompile needed;
;; config.setup deep-merges and the keymaps are command strings, so
;; this is all it takes to iterate on configuration alone
;;
;; both entry points are globals on purpose: each Conjure eval is its
;; own chunk, so locals don't survive between evals — a lone (reload)
;; form only sees what lives in the global environment. dev-opts
;; stays a local, captured as an upvalue by these closures; edit it
;; and re-evaluate the file to pick the new value up
(global setup (fn setup [?opts]
                (let [snapshot (?. package.loaded :codeboomer.config :config)
                      opts (or ?opts dev-opts snapshot {})
                      cb (require :codeboomer)]
                  ((. cb :setup) opts)
                  (vim.notify "codeboomer: setup re-applied"
                              vim.log.levels.INFO))))

;; the full cycle: close the shared sqlite handle (the fresh singleton
;; would otherwise open a second connection), drop every codeboomer.*
;; module from the require cache, re-require and re-setup. The
;; :Codeboomer command survives it all — plugin/codeboomer.lua's
;; handlers require lazily, at call time, so they pick up the fresh
;; modules without any re-registration
(global reload
        (fn reload [?opts]
          (let [snapshot (?. package.loaded :codeboomer.config :config)
                singleton (. package.loaded :codeboomer.singleton)]
            (when singleton
              (pcall (. singleton :close-db)))
            (each [k (pairs package.loaded)]
              (when (k:find :^codeboomer)
                (tset package.loaded k nil)))
            (setup (or ?opts dev-opts snapshot))
            (vim.notify "codeboomer: reloaded" vim.log.levels.INFO))))

(reload)
