{ config, pkgs, ... }:

{
  imports = [
    ./gpu.nix
    ./steam.nix
    # Future: ./monitors.nix, ./audio.nix, ./boot.nix, etc.
  ];

  networking.hostName = "theConstruct";

  # Bootloader — GRUB for Windows dual-boot
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      useOSProber = true;
    };
  };
}
