-- Compile Fennel to Lua on save via nfnl.
-- Note: the key is "setup-buffer" (Fennel naming), so bracket access is
-- required in Lua — dot access would parse as `setup minus buffer()`.
require("nfnl.callback")["setup-buffer"]({ file = vim.fn.expand("%"), buf = vim.api.nvim_get_current_buf() })
