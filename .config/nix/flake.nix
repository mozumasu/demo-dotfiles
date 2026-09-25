{
  description = "My dotfiles";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    darwin.url = "github:nix-darwin/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs =
    {
      nixpkgs,
      darwin,
      home-manager,
      ...
    }:
    {
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
        ];
      };
    };
}
