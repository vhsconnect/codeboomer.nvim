(local {: autoload} (require :nfnl-plugin-example.nfnl.module))

(local notify (autoload :nfnl-plugin-example.nfnl.notify))

(fn setup []
  (notify.info "nfnl module compiled; setup() invoked"))

(vim.notify "test.fnl: exporting setup via module table" vim.log.levels.INFO)

{: setup}
