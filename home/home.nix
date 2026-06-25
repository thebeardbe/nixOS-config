{ config, pkgs, theme, ... }:

{
  # Import all program/config modules — each one enables+configures a specific tool
  imports = [
     ./modules/yazi.nix       # Terminal file manager
     ./modules/appearance.nix # GTK/Qt theming, cursor, kitty, wofi
     ./modules/hyprlock.nix   # Lockscreen
     ./modules/hypridle.nix   # Auto-sleep / idle management
     ./modules/neovim.nix     # Neovim editor with LSPs
     ./modules/starship.nix   # Shell prompt + Zsh config
     ./packages.nix          # All user packages (apps, fonts, tools)
     ./modules/hyprland.nix   # Window manager + keybinds + hypr ecosystem
     ./modules/waybar.nix     # Status bar
     ./modules/agent.nix      # Node.js / npm / pi-coding-agent
     ./modules/secrets.nix   # Secret option declarations
  ];

  home.username = "thebeardbe";
  home.homeDirectory = "/home/thebeardbe";
  home.stateVersion = "25.11"; 

  targets.genericLinux.enable = true;

  home.file = {
    ".screenrc".source = ./files/screenrc;
  };

  home.sessionVariables = {
    # EDITOR = "vim";  # Set default editor (neovim handles this via defaultEditor)
  };

  # --- Bash config ---
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      conf = "cd ~/nixos-config && v";      # Open config in neovim
      rebuild = "sudo nixos-rebuild switch --flake .#$(hostname)";
    };
  };

  # Enable the SSH agent (manages keys, auto-adds to agent)
  services.ssh-agent.enable = true;

  # --- SSH config ---
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      # Auto-add all keys to the running SSH agent
      "*" = {
        addKeysToAgent = "yes";
      };
      # GitHub-specific: use the dedicated GitHub SSH key
      "github.com" = {
        hostname = "github.com";
        identityFile = "~/.ssh/github";
      };
    };
  };

  # --- Git config ---
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "TheBeardBE";
        email = "bunker@achter.be";
      };
    };
    # No sshCommand needed here — SSH config above handles the correct key
  };

  # Force dark mode for GTK4/libadwaita apps (Settings, Nautilus, etc.)
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  programs.home-manager.enable = true;
}
