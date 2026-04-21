{ config, pkgs, theme, ... }:

{
  # Import all program configs. 
  imports = [
     ./modules/yazi.nix
     ./modules/appearance.nix
     ./modules/hyprlock.nix
     ./modules/hypridle.nix
     ./modules/neovim.nix
     ./modules/starship.nix
     ./modules/packages.nix
     ./modules/hyprland.nix
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
      # hms = "home-manager switch --flake ~/.config/home-manager";
      conf = "nano ~/.config/home-manager/home.nix";
      # update = "nix flake update && hms";
      rebuild = "sudo nixos-rebuild switch --flake .#foxyNix";
    };
  };

  # 1. Zorg dat de agent draait
  services.ssh-agent.enable = true;

  # 2. Leer SSH welke sleutel bij GitHub hoort (Universal fix)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes"; # De nieuwe plek voor deze optie
      };
      "github.com" = {
        hostname = "github.com";
        identityFile = "~/.ssh/github"; # Pad naar je PRIVATE key
      };
    };
  };

  # 3. Git hoeft nu alleen je user info te weten
  programs.git = {
    enable = true;
    # Verplaats deze van de root van git naar settings.user
    settings = {
      user = {
        name = "TheBeardBE";
        email = "bunker@achter.be";
      };
    };
    # Je hoeft hier GEEN sshCommand meer te zetten!
  };

  # ----------------------------
  
  # Theme settings define dark
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
  programs.home-manager.enable = true;
}
