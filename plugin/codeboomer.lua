if vim.g.loaded_codeboomer then
  return
end
vim.g.loaded_codeboomer = 1

local subcommands = {}

subcommands.SetPane = function()
  require("codeboomer").SetPane()
end

subcommands.SendKeys = function(opts)
  local codeboomer = require("codeboomer")
  codeboomer.SendKeys(opts)
end

subcommands.SendKeysOO = function(opts)
  local codeboomer = require("codeboomer")
  codeboomer.SendKeysOO(opts)
end

subcommands.Annotate = function(opts)
  local codeboomer = require("codeboomer")
  codeboomer.Annotate(opts)
end

subcommands.SendWithDirective = function()
  local codeboomer = require("codeboomer")
  codeboomer.SendWithDirective()
end

vim.api.nvim_create_user_command("Codeboomer", function(opts)
  local name = opts.fargs[1]
  local run = subcommands[name]
  if not run then
    vim.notify(("codeboomer: unknown subcommand %q"):format(name), vim.log.levels.ERROR)
    vim.notify("codeboomer: available: " .. table.concat(vim.tbl_keys(subcommands), " "), vim.log.levels.INFO)
    return
  end
  run(opts)
end, {
  nargs = "*",
  range = true,
  desc = "codeboomer.nvim",
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
