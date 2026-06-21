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

    mkHost = host: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/${host}/default.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.thebeardbe = { ... }: {
            imports = [
              ./home/home.nix
              ./hosts/${host}/home.nix
            ];
          };
          home-manager.extraSpecialArgs = { theme = themeConfig; };
        }
      ];
    };
  in {
    nixosConfigurations = {
      foxyNix     = mkHost "laptop";
      theConstruct = mkHost "desktop";
    };
  };
}
