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
    # Load the central theme config (colors, fonts, spacing, opacity)
    # Shared across all modules (hyprland, waybar, kitty, wofi, starship, hyprlock)
    themeConfig = builtins.fromJSON (builtins.readFile ./theme.json);
  in {
    nixosConfigurations.foxyNix = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        ./system/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.thebeardbe = import ./home/home.nix;
          
          # Pass the theme to home.nix and all imported modules via extraSpecialArgs
          # Each module that needs styling (appearance, hyprland, waybar, etc.) receives `theme` as an argument
          home-manager.extraSpecialArgs = { 
            theme = themeConfig; 
          };
        }
      ];
    };
  };
}
