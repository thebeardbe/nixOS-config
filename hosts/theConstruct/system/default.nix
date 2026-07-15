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

  # Filesystem support for storage drives (exfat + NTFS via ntfs-3g)
  boot.supportedFilesystems = [ "exfat" ];

  # Storage drives — auto-mount at boot (nofail = don't block boot)
  fileSystems = {
    "/mnt/golden-city" = {
      device = "/dev/disk/by-uuid/B89B-399D";
      fsType = "exfat";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" "nofail" ];
    };
    "/mnt/blue-fire" = {
      device = "/dev/disk/by-uuid/8CB1-7A97";
      fsType = "exfat";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" "nofail" ];
    };
    "/mnt/black-glass" = {
      device = "/dev/disk/by-uuid/32CA-F4E4";
      fsType = "exfat";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" "nofail" ];
    };
    "/mnt/silver-light" = {
      device = "/dev/disk/by-uuid/BAE0-0704";
      fsType = "exfat";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" "nofail" ];
    };
    "/mnt/middle-country" = {
      device = "/dev/disk/by-uuid/F270574F705719A5";
      fsType = "ntfs-3g";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" "nofail" ];
    };
    "/mnt/the-other" = {
      device = "/dev/disk/by-uuid/368035BA80358203";
      fsType = "ntfs-3g";
      options = [ "uid=1000" "gid=100" "fmask=0022" "dmask=0022" "nofail" ];
    };
  };
}
