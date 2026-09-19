{ config, lib, pkgs, ... }:

{
  imports = [
    ./gpu.nix
    ./steam.nix
    # Future: ./audio.nix, ./boot.nix, etc.
  ];

  networking.hostName = "theConstruct";

  # Bootloader — GRUB for Windows dual-boot
  #
  # The ESP is mounted at /boot/efi and /boot is a plain directory on the root
  # ext4 filesystem. install-grub.pl only copies kernels/initrds into the boot
  # path when it is on a different filesystem than /nix/store, so with this
  # layout GRUB reads them straight from /nix/store and the 1G ESP stays free.
  # Previously /boot was the ESP and the kernels filled it, which silently
  # broke every rebuild that pulled in a new kernel.
  boot.loader = {
    efi.canTouchEfiVariables = true;
    efi.efiSysMountPoint = "/boot/efi";
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      useOSProber = true;
      # Override the mirroredBoots entry generated from "device" above, so the
      # existing efiBootloaderId is kept. Firmware entry Boot0000 already points
      # at \EFI\NixOS-boot\grubx64.efi, so reusing the id leaves BootOrder
      # unchanged; the default id would become "NixOS-boot-efi" and add a
      # second firmware entry.
      mirroredBoots = lib.mkForce [
        {
          path = "/boot";
          devices = [ "nodev" ];
          efiSysMountPoint = "/boot/efi";
          efiBootloaderId = "NixOS-boot";
        }
      ];
    };
  };

  # Filesystem support for storage drives (exfat + NTFS via the kernel ntfs3 driver)
  boot.supportedFilesystems = [ "exfat" "ntfs3" ];

  # Firewall: Packet (Quick Share with Android) — per GitHub issues: 9300/tcp, 5353/udp (mDNS), 5355/udp (LLMNR)
  networking.firewall.allowedTCPPorts = [ 9300 27000 27001 27002 27003 27004 27005 27006 27007 27008 27009 ];
  networking.firewall.allowedUDPPorts = [ 5353 5355 27000 27001 27002 27003 27004 27005 27006 27007 27008 27009 ];

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
