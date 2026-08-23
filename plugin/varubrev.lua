if vim.g.loaded_varubrev then
  return
end
vim.g.loaded_varubrev = 1

local subcommands = {}

subcommands.SetPane = function()
  require("varubrev").SetPane()
end

subcommands.SendKeys = function(opts)
  local varubrev = require("varubrev")
  varubrev.SendKeys(opts)
end

subcommands.SendKeysOO = function(opts)
  local varubrev = require("varubrev")
  varubrev.SendKeysOO(opts)
end

subcommands.Annotate = function(opts)
  local varubrev = require("varubrev")
  varubrev.Annotate(opts)
end

subcommands.SendWithDirective = function()
  local varubrev = require("varubrev")
  varubrev.SendWithDirective()
end

vim.api.nvim_create_user_command("Varubrev", function(opts)
  local name = opts.fargs[1]
  local run = subcommands[name]
  if not run then
    vim.notify(("varubrev: unknown subcommand %q"):format(name), vim.log.levels.ERROR)
    vim.notify("varubrev: available: " .. table.concat(vim.tbl_keys(subcommands), " "), vim.log.levels.INFO)
    return
  end
  run(opts)
end, {
  nargs = "*",
  range = true,
  desc = "varubrev.nvim",
  complete = function(arg_lead)
    local matches = {}
    for name in pairs(subcommands) do
      if vim.startswith(name, arg_lead) then
        table.insert(matches, name)
      end
    end
    return matches
  end,
})
