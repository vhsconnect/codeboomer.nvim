local M = {}

M.defaults = {
  url = "https://httpbin.org/get",
}

M.config = M.defaults

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
