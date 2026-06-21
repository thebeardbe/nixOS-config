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

    # Shared home-manager base (same for all machines)
    sharedHomeConfig = {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = { theme = themeConfig; };
    };

    # Helper to build a machine config
    mkMachine = machine: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ./system/machines/${machine}.nix
        home-manager.nixosModules.home-manager
        sharedHomeConfig
        {
          home-manager.users.thebeardbe = { ... }: {
            imports = [
              ./home/home.nix
              ./home/machines/${machine}.nix
            ];
          };
        }
      ];
    };
  in {
    nixosConfigurations = {
      foxyNix = mkMachine "laptop";
      desktop  = mkMachine "theConstruct";
    };
  };
}
