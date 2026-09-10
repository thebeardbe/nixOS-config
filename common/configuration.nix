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
     ./modules/power.nix
     ./modules/removable-media.nix
     ./modules/desktop.nix
     ./modules/virtualisation.nix
     ./modules/graphics.nix
     ./modules/system-packages.nix
    ];

  # Swap file
  swapDevices = [ { device = "/swapfile"; size = 8192; } ];

  system.stateVersion = "25.11";
}
