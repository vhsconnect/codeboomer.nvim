local config = require("compis.config")
local curl = require("plenary.curl")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

function M.ping()
  local url = config.config.url
  curl.get(url, {
    callback = function(out)
      if out.status ~= 200 then
        vim.schedule(function()
          vim.notify("compis: request failed – HTTP " .. out.status, vim.log.levels.ERROR)
        end)
        return
      end
      vim.schedule(function()
        vim.notify(out.body, vim.log.levels.INFO)
      end)
    end,
  })
end

return M
