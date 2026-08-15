local project_root = "/home/vhs/Repos/compis.nvim"

-- Note: the nix nvim wrapper already puts every plugin (including fzf-lua)
-- from vim-pack-dir on the default runtimepath, so no extra rtp entry is
-- needed for `require("fzf-lua")`.

vim.opt.runtimepath:append(project_root)
require("compis").setup()
