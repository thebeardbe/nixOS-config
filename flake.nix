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
    themeConfig = builtins.fromJSON (builtins.readFile ./theme.json);

    # Shared home-manager config (same for all machines)
    homeConfig = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.thebeardbe = import ./home/home.nix;
      home-manager.extraSpecialArgs = { theme = themeConfig; };
    };
  in {
    nixosConfigurations = {
      foxyNix = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./system/machines/laptop.nix
          home-manager.nixosModules.home-manager
          homeConfig
        ];
      };

      desktop = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./system/machines/desktop.nix
          home-manager.nixosModules.home-manager
          homeConfig
        ];
      };
    };
  };
}
