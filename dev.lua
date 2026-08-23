local project_root = "/home/vhs/Repos/codeboomer.nvim"

-- <leader> must be set BEFORE any <leader> mappings are created — the
-- prefix is resolved when the map is defined, not when it is pressed.
vim.g.mapleader = " "
-- silence space's default "move right" so an abandoned sequence does nothing
vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")

-- Note: the nix nvim wrapper already puts every plugin (including fzf-lua)
-- from vim-pack-dir on the default runtimepath, so no extra rtp entry is
-- needed for `require("fzf-lua")`.

vim.opt.runtimepath:prepend(project_root)

local function reload_codeboomer()
  -- 1. Recompile fnl/ -> lua/
  require("nfnl.api")["compile-all-files"](project_root)

  -- 2. Drop cached codeboomer modules so require() returns the fresh code
  for name in pairs(package.loaded) do
    if name == "codeboomer" or name:find("^codeboomer%.") then
      package.loaded[name] = nil
    end
  end

  -- 3. Re-source plugin/codeboomer.lua (reset the load guard first)
  vim.g.loaded_codeboomer = nil
  vim.cmd.source(project_root .. "/plugin/codeboomer.lua")

  -- 4. Re-run setup
  require("codeboomer").setup(opts)

  vim.notify("codeboomer: reloaded", vim.log.levels.INFO)
end

local opts = {
  keybindings = {
    send = "<leader>cs",
    send_visual = "<leader>cs",
    send_visualOO = "<leader>cc",
    send_with_directive = "<leader>cd",
    pane = "<leader>cp",
    annotate = "<leader>ca",
  },
}

vim.api.nvim_create_user_command("CodeboomerReload", reload_codeboomer, {
  desc = "Recompile (fnl->lua) and reload codeboomer.nvim",
})

require("codeboomer").setup(opts)
