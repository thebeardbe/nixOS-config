{ config, pkgs, ... }:

{
  imports = [
    ./gpu.nix
    ./steam.nix
    # Future: ./monitors.nix, ./audio.nix, ./boot.nix, etc.
  ];

  networking.hostName = "theConstruct";

  # Bootloader — configure during install (e.g. GRUB for Windows dual-boot)
  # boot.loader.grub = {
  #   enable = true;
  #   devices = [ "nodev" ];
  #   efiSupport = true;
  #   enableCryptodisk = true;
  # };
}
