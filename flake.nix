{
  description = "codeboomer.nvim dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          testLua = pkgs.luajit.withPackages (ps: [
            ps.busted
            ps.coxpcall
          ]);
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.babashka
            ];
            shellHook = ''
              export CODEBOOMER_PATH="$PWD"
              export LD_LIBRARY_PATH="${pkgs.sqlite.out}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              export NVIM_TEST_RUNNER="${pkgs.neovim-unwrapped}/bin/nvim"
              export NVIM_PRG="${pkgs.neovim-unwrapped}/bin/nvim"
              export NVIM_TEST_LUA_PATH="${testLua}/share/lua/5.1/?.lua;${testLua}/share/lua/5.1/?/init.lua"
              export NVIM_TEST_LUA_CPATH="${testLua}/lib/lua/5.1/?.so"
              export SQLITE_LUA_PATH="${pkgs.vimPlugins.sqlite-lua}"
            '';
          };
        }
      );
    };
}
