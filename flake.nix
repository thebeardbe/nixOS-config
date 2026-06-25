{
  description = "Renaissance Man Unified Config";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Bleeding-edge nixpkgs for specific packages (signal-desktop, etc.)
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Private secrets — optional flake input.
    # nix-secrets = {
    #   url = "git+ssh://git@your-server/filip/nix-secrets";
    #   flake = true;
    # };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs: 
  let
    system = "x86_64-linux";
    themeConfig = builtins.fromJSON (builtins.readFile ./theme.json);
    unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };

    secretModulesFor = host: if inputs ? nix-secrets then [
      inputs.nix-secrets.nixosModules.common
      inputs.nix-secrets.nixosModules.${host}
    ] else [];

    mkHost = host: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; unstable = unstable; };
      modules = [
        ./hosts/${host}/default.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.thebeardbe = { ... }: {
            imports = [
              ./home/home.nix
              ./hosts/${host}/home/default.nix
            ];
          };
          home-manager.extraSpecialArgs = { 
            inherit unstable;
            theme = themeConfig; 
          };
        }
      ] ++ secretModulesFor host;
    };
  in {
    nixosConfigurations = {
      foxyNix      = mkHost "foxyNix";
      theConstruct = mkHost "theConstruct";
    };
  };
}
