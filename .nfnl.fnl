{:verbose :true
 :trust :true
 ;; Restrict compilation to the fnl/ tree. Without this, the default
 ;; "*.fnl" pattern also compiles flsproject.fnl (fennel-ls's project
 ;; config) into a stray lua/flsproject.lua.
 :source-file-patterns [:fnl/*.fnl :fnl/**/*.fnl :fnl/*.fnlm :fnl/**/*.fnlm]}
