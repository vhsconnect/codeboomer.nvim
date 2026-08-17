local project_root = "/home/vhs/Repos/varubrev.nvim"

-- <leader> must be set BEFORE any <leader> mappings are created — the
-- prefix is resolved when the map is defined, not when it is pressed.
vim.g.mapleader = " "
-- silence space's default "move right" so an abandoned sequence does nothing
vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>")

-- Note: the nix nvim wrapper already puts every plugin (including fzf-lua)
-- from vim-pack-dir on the default runtimepath, so no extra rtp entry is
-- needed for `require("fzf-lua")`.

vim.opt.runtimepath:append(project_root)

local function reload_varubrev()
  -- 1. Recompile fnl/ -> lua/
  require("nfnl.api")["compile-all-files"](project_root)

  -- 2. Drop cached varubrev modules so require() returns the fresh code
  for name in pairs(package.loaded) do
    if name == "varubrev" or name:find("^varubrev%.") then
      package.loaded[name] = nil
    end
  end

  -- 3. Re-source plugin/varubrev.lua (reset the load guard first)
  vim.g.loaded_varubrev = nil
  vim.cmd.source(project_root .. "/plugin/varubrev.lua")

  -- 4. Re-run setup
  require("varubrev").setup(opts)

  vim.notify("varubrev: reloaded", vim.log.levels.INFO)
end

local opts = {
  send = "<leader>cs",
  send_visual = "<leader>cs",
  pane = "<leader>cp",
}

vim.api.nvim_create_user_command("VarubrevReload", reload_varubrev, {
  desc = "Recompile (fnl->lua) and reload varubrev.nvim",
})

require("varubrev").setup(opts)
