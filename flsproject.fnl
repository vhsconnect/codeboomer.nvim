;; needed so that fennel-ls does not trip on macros using nfnl
;; 
{:fennel-path "./fnl/?.fnl;./fnl/?/init.fnl;./test/fnl/?.fnl"
 :macro-path "./fnl/?.fnlm;./fnl/?/init.fnlm;./fnl/?.fnl;./fnl/?/init-macros.fnl;./fnl/?/init.fnl"
 :extra-globals "vim vim.* describe it before_each after_each pending"}
