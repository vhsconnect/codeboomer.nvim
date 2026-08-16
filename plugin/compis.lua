if vim.g.loaded_compis then
  return
end
vim.g.loaded_compis = 1

local subcommands = {}

subcommands.ParseSessions = function()
  require("compis").ParseSessions()
end

subcommands.ParsePanes = function()
  require("compis").ParsePanes()
end

subcommands.Compose = function()
  require("compis").Compose()
end

subcommands.SetPane = function()
  require("compis").SetPane()
end

subcommands.SendKeys = function(opts)
  local compis = require("compis")
  compis.SendKeys(opts)
end

vim.api.nvim_create_user_command("Compis", function(opts)
  local name = opts.fargs[1]
  local run = subcommands[name]
  if not run then
    vim.notify(("compis: unknown subcommand %q"):format(name), vim.log.levels.ERROR)
    vim.notify("compis: available: " .. table.concat(vim.tbl_keys(subcommands), " "), vim.log.levels.INFO)
    return
  end
  run(opts)
end, {
  nargs = "*",
  range = true,
  desc = "compis.nvim",
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
