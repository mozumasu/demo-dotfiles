{
  description = "My dotfiles";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
    darwin.url = "github:nix-darwin/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { nixpkgs, darwin, ... }: {
    darwinConfigurations.arabica = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        {
	  system.stateVersion = 5;
          nix.settings.experimental-features = "nix-command flakes";
          system.primaryUser = "mozumasu";
          users.users."mozumasu".home = "/Users/mozumasu";
	  system.keyboard.enableKeyMapping = true;
	  system.keyboard.remapCapsLockToControl = true;
        }
      ];
    };
  };
}
