if vim.g.loaded_compis then
  return
end
vim.g.loaded_compis = 1

vim.api.nvim_create_user_command("Compis", function()
  require("compis").ping()
end, { desc = "Fetch a test URL and display the response" })
