(when package.loaded.jit
  (let [(ok coxpcall) (pcall require :coxpcall)]
    (when ok
      (set _G.pcall coxpcall.pcall))))

(local helpers (require :nvim-test.helpers))
(local cb-helpers (require :cb_helpers))

(fn [busted _helper options]
  (set helpers.options options)
  (busted.subscribe [:suite :start] #(cb-helpers.cleanup-scratch-root))
  (busted.subscribe [:suite :end] #(cb-helpers.cleanup-scratch-root))
  true)
