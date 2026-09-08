{
  description = "codeboomer.nvim dev shell";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          default = pkgs.mkShell {
            # ./test-codeboomer and dev.lua resolve the plugin dir through
            # CODEBOOMER_PATH — set it to the live checkout (not the flake's
            # store copy), so edits under fnl/ and lua/ are what loads
            shellHook = ''
              export CODEBOOMER_PATH="$PWD"
              export LD_LIBRARY_PATH="${pkgs.sqlite.out}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            '';
          };
        });
    };
}
