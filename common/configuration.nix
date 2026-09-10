# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include all systemwide modules.
     ./modules/bluetooth.nix 
     ./modules/touchpad.nix
     ./modules/users.nix
     ./modules/security.nix
     ./modules/hardware.nix
     ./modules/audio.nix
     ./modules/networking.nix
     ./modules/locale.nix
     ./modules/nix.nix
     ./modules/nix-gc.nix
     ./modules/flake-update.nix
     ./modules/portals.nix
     ./modules/greetd.nix
    ];

  # Use dbus-broker (GNOME default, avoids switch inhibitor warning)
  services.dbus.implementation = "broker";

  # Enable stock power management tools
  powerManagement.enable = true;

  # Prevent overheating on Intel CPU
  services.thermald.enable = true;

  # Trim SSD for performance
  services.fstrim.enable = true;

  # UDisks2 — daemon for mounting removable media (USB sticks, SD cards, external drives)
  # udiskie (home-manager) talks to this over D-Bus to auto-mount on insertion
  services.udisks2.enable = true;

  # Kernel support for removable-media filesystems: exFAT (SD cards/USB sticks)
  # and NTFS (Windows drives, via kernel ntfs3 driver)
  boot.supportedFilesystems = [ "exfat" "ntfs3" ];

  # Swap file
  swapDevices = [ { device = "/swapfile"; size = 8192; } ];

  # Flatpak
  services.flatpak.enable = true;

  # Let Hyprland handle the power key instead of systemd
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # Docker
  virtualisation.docker.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    curl
    htop
    pulseaudio  # pactl CLI for PipeWire-Pulse audio profile switching
    pavucontrol  # PulseAudio GUI (switch audio profiles)

    # Recovery: unlock the graphical session from a TTY when hyprlock crashes
    (pkgs.writeShellScriptBin "unlock-session" (builtins.readFile ../recovery-scripts/unlock-session))
  ];

  # List services that you want to enable:

  system.stateVersion = "25.11";

  # Make Hyprland available system-wide (needed for greetd to launch it)
  # The actual theming/binds are configured in home-manager: home/modules/hyprland.nix
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # environment settings
  environment.sessionVariables = {
     # If cursor becomes invisible
     WLR_NO_HARDWARE_CURSORS = "1";

     # Hint electron apps to use wayland
     NIXOS_OZONE_WL = "1";
  };

  hardware = {
    # OpenGL
    graphics.enable = true;

    # Most Wayland compositors need this
    # nvidia.modesetting.enable = true;
  };

  # enable gVFS for mounting sftp in yazi under /run/user/1000/gvfs
  services.gvfs.enable = true;
}
