{
  description = "yian dotfiles - shared on maverick, frontera, and p620";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, nix-homebrew, ... }:
    let
      user = "yian";
      mkDarwin = hostname:
        nix-darwin.lib.darwinSystem {
          specialArgs = { inherit user hostname; };
          modules = [
            ./configuration.nix
            ./hosts/${hostname}.nix
            nix-homebrew.darwinModules.nix-homebrew
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit user hostname; };
              home-manager.users.${user} = import ./home.nix;
            }
          ];
        };
    in
    {
      darwinConfigurations.maverick = mkDarwin "maverick";
      darwinConfigurations.frontera = mkDarwin "frontera";

      homeConfigurations.p620 = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        extraSpecialArgs = { inherit user; hostname = "p620"; };
        modules = [ ./home.nix ./hosts/p620.nix ];
      };

      # Bootstrap and rebuild use the same locked Home Manager as the modules.
      packages.x86_64-linux.home-manager = home-manager.packages.x86_64-linux.home-manager;
    };
}
