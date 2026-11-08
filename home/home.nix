{ config, lib, pkgs, theme, ... }:

{
  # Import all program/config modules — each one enables+configures a specific tool
  imports = [
     ./modules/yazi.nix       # Terminal file manager
     ./modules/appearance.nix # GTK/Qt theming, cursor, kitty, fuzzel
     ./modules/hyprlock.nix   # Lockscreen
     ./modules/hypridle.nix   # Auto-sleep / idle management
     ./modules/audio.nix      # PipeWire/WirePlumber quirks (JBL USB headsets)
    ./modules/battery-monitor.nix # Battery alerts at 10% and 5%
     ./modules/neovim.nix     # Neovim editor with LSPs
     ./modules/udiskie.nix   # Auto-mount USB/SD/external drives
     ./modules/starship.nix   # Shell prompt + Zsh config
     ./packages.nix          # All user packages (apps, fonts, tools)
     ./modules/hyprland.nix   # Window manager + keybinds + hypr ecosystem
     ./modules/waybar.nix     # Status bar
     ./modules/agent.nix      # Node.js / npm / pi-coding-agent
     ./modules/proton.nix    # Proton CLI (Mail, Drive, Calendar, Contacts) + share wrappers
     ./modules/secrets.nix   # Secret option declarations
     ./modules/flake-aliases.nix # Shared rebuild/update aliases for bash + zsh
  ];

  home.username = "thebeardbe";
  home.homeDirectory = "/home/thebeardbe";
  home.stateVersion = "25.11"; 

  targets.genericLinux.enable = true;

  home.file = {
    ".screenrc".source = ./files/screenrc;
  };

  # The main Hyprland config is deployed as a real file, not a home-manager
  # symlink.
  #
  # greetd starts Hyprland with `-c ~/.config/hypr/hyprland.lua`, and Hyprland
  # resolves that symlink once at startup. `hyprctl reload` (Super+Shift+R) then
  # re-reads the resolved *store path*, so with a symlink it keeps reloading the
  # generation that was current at login and never sees a rebuilt config - which
  # makes Super+Shift+R silently useless. A real file keeps the path stable, so a
  # rebuild followed by a reload picks up the new content.
  #
  # The swap must be atomic: Hyprland reloads when the file changes, so the old
  # delete-then-install left a window in which the path did not exist and the
  # compositor printed "cannot open .../hyprland.lua: No such file or directory"
  # in its on-screen config-error banner (2026-11-08 09:27:50, the same second
  # home-manager activated this hook). A sibling temp file renamed over the target
  # means the path always holds either the old or the new content.
  home.activation.deployHyprlandLua = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/.config/hypr"
    run install -m 0644 ${./files/hyprland.lua} "$HOME/.config/hypr/.hyprland.lua.new"
    run mv -f "$HOME/.config/hypr/.hyprland.lua.new" "$HOME/.config/hypr/hyprland.lua"
  '';

  # --- Bash config ---
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      conf = "cd \"$(nixos-config-dir)\" && nvim"; # Open config in neovim
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
      # Private git server on sellars (sellars:~/Docker/git-server). SSH only for
      # read/write; HTTP on port 8082 is read-only. Remotes look like:
      #   ssh://sellars-git/srv/git/<repo>.git
      "sellars-git" = {
        hostname = "sellars";
        user = "git";
        port = 2222;
        identityFile = "~/.ssh/sellars";
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
