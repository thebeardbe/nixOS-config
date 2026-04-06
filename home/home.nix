{ config, pkgs, theme, ... }:

{
  # Import all program configs. 
  imports = [
     ./modules/starship.nix
     ./modules/packages.nix
     ./modules/hyprland.nix
     ./modules/waybar.nix 
  ];

  home.username = "thebeardbe";
  home.homeDirectory = "/home/thebeardbe";
  home.stateVersion = "25.11"; 

  targets.genericLinux.enable = true;

  home.file = {
    # Hier kun je later specifieke dotfiles naar de Nix store laten wijzen
  };

  home.sessionVariables = {
    # EDITOR = "vim";
  };

  # --- Define program specific configs ---
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      hms = "home-manager switch --flake ~/.config/home-manager";
      conf = "nano ~/.config/home-manager/home.nix";
      update = "nix flake update && hms";
      rebuild = "sudo nixos-rebuild switch";
    };
  };

  # ----------------------------

  programs.home-manager.enable = true;
}
