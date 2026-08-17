local project_root = "/home/vhs/Repos/compis.nvim"

-- <leader> must be set BEFORE any <leader> mappings are created — the
-- prefix is resolved when the map is defined, not when it is pressed.
vim.g.mapleader = " "
-- silence space's default "move right" so an abandoned sequence does nothing
vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")

-- Note: the nix nvim wrapper already puts every plugin (including fzf-lua)
-- from vim-pack-dir on the default runtimepath, so no extra rtp entry is
-- needed for `require("fzf-lua")`.

vim.opt.runtimepath:append(project_root)

local function reload_compis()
  -- 1. Recompile fnl/ -> lua/
  require("nfnl.api")["compile-all-files"](project_root)

  -- 2. Drop cached compis modules so require() returns the fresh code
  for name in pairs(package.loaded) do
    if name == "compis" or name:find("^compis%.") then
      package.loaded[name] = nil
    end
  end

  -- 3. Re-source plugin/compis.lua (reset the load guard first)
  vim.g.loaded_compis = nil
  vim.cmd.source(project_root .. "/plugin/compis.lua")

  -- 4. Re-run setup
  require("compis").setup(opts)

  vim.notify("compis: reloaded", vim.log.levels.INFO)
end

local opts = {
  send = "<leader>cs",
  send_visual = "<leader>cs",
  pane = "<leader>cp",
}

vim.api.nvim_create_user_command("CompisReload", reload_compis, {
  desc = "Recompile (fnl->lua) and reload compis.nvim",
})

require("compis").setup(opts)
