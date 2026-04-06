{
  description = "Renaissance Man Unified Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: 
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true; # Jouw instelling overgenomen
    };
    # Laad de centrale styling
    themeConfig = builtins.fromJSON (builtins.readFile ./theme.json);
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ./system/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.thebeardbe = import ./home/home.nix;
          
          # Geef de theme door aan home.nix en alle modules
          home-manager.extraSpecialArgs = { 
            theme = themeConfig; 
          };
        }
      ];
    };
  };
}
