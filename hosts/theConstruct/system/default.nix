{ config, pkgs, ... }:

{
  imports = [
    ./gpu.nix
    ./steam.nix
    # Future: ./audio.nix, ./boot.nix, etc.
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

  # exfat support
  boot.supportedFilesystems = [ "exfat" ];

  # Storage drives — auto-mount at boot
  fileSystems = {
    "/mnt/golden-city" = {
      device = "/dev/disk/by-uuid/B89B-399D";
      fsType = "exfat";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" ];
    };
    "/mnt/blue-fire" = {
      device = "/dev/disk/by-uuid/8CB1-7A97";
      fsType = "exfat";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" ];
    };
    "/mnt/black-glass" = {
      device = "/dev/disk/by-uuid/32CA-F4E4";
      fsType = "exfat";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" ];
    };
    "/mnt/silver-light" = {
      device = "/dev/disk/by-uuid/BAE0-0704";
      fsType = "exfat";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" ];
    };
  };
}
