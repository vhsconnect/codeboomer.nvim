if vim.g.loaded_compis then
  return
end
vim.g.loaded_compis = 1

vim.api.nvim_create_user_command("Compis", function()
  require("compis").ask("What is the best month of the year and why?")
end, { desc = "Ask the AI a question and display the response" })
