{
  description = "My dotfiles";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    darwin.url = "github:nix-darwin/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      nixpkgs,
      darwin,
      home-manager,
      nix-homebrew,
      treefmt-nix,
      ...
    }:
    let
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
    in
    {
      # nix fmt / nix run .#formatterの実体
      formatter.aarch64-darwin = treefmtEval.config.build.wrapper;
      checks.aarch64-darwin.formatting = treefmtEval.config.build.check ./.;
      darwinConfigurations.arabica = darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = [
          ./darwin/system.nix
          {
            nix.settings.experimental-features = "nix-command flakes";
            system.primaryUser = "mozumasu";
            users.users."mozumasu".home = "/Users/mozumasu";
          }
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              users."mozumasu" = import ./home-manager;
            };
          }
          ./darwin/homebrew.nix
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              user = "mozumasu";
              autoMigrate = true;
            };
          }
        ];
      };
    };
}
