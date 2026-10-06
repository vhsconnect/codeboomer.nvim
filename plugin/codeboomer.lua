if vim.g.loaded_codeboomer then
    return
end
vim.g.loaded_codeboomer = 1

-- the agent bridge generates its CLI shim (~/.local/share/nvim/
-- codeboomer-agent) on load, baking in the running environment
require("codeboomer.agent")

local subcommands = {}

subcommands.SetPane = function()
    require("codeboomer").SetPane()
end

subcommands.ResetSession = function()
    require("codeboomer").ResetSession()
end

subcommands.Review = function(opts)
    -- fargs[1] is the subcommand name itself; the PR number, if any,
    -- is the second farg
    require("codeboomer.review-mode").open(tonumber(opts.fargs[2]))
end

subcommands.PostReview = function()
    require("codeboomer.review-mode").post()
end

subcommands.PullReview = function()
    require("codeboomer.review-mode").pull()
end

subcommands.LaunchReviewer = function()
    require("codeboomer").LaunchReviewer()
end

subcommands.SendPrompt = function(opts)
    require("codeboomer").SendPrompt(opts)
end

subcommands.SendLastPrompt = function(opts)
    require("codeboomer").SendLastPrompt(opts)
end

subcommands.SendSelection = function(opts)
    require("codeboomer").SendSelection(opts)
end

subcommands.AskOneOff = function(opts)
    require("codeboomer").AskOneOff(opts)
end

subcommands.Annotate = function(opts)
    require("codeboomer").Annotate(opts)
end

subcommands.FlushWithDirective = function()
    require("codeboomer").FlushWithDirective()
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
