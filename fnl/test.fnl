(local {: autoload} (require :nfnl-plugin-example.nfnl.module))

(local notify (autoload :nfnl-plugin-example.nfnl.notify))

(fn setup []
  (notify.info "Hello, World! Hi from fennel!!!! - you're too kind"))

{: setup}
