{ config, pkgs, ... }:

{
  imports = [
    ./steam.nix
  ];

  networking.hostName = "foxyNix";
  mySystem.touchpad.enable = true;

  # Bootloader — systemd-boot with Ubuntu dual-boot
  boot.loader.systemd-boot = {
    enable = true;
    consoleMode = "max";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.extraEntries = {
    "ubuntu.conf" = ''
      title Ubuntu
      efi /EFI/ubuntu/shimx64.efi
    '';
  };

  # Firewall: Packet (Quick Share with Android) — same ports as theConstruct
  networking.firewall.allowedTCPPorts = [ 9300 27000 27001 27002 27003 27004 27005 27006 27007 27008 27009 ];
  networking.firewall.allowedUDPPorts = [ 5353 5355 27000 27001 27002 27003 27004 27005 27006 27007 27008 27009 ];

  # Silent boot
  boot.plymouth.enable = true;
  boot.kernelParams = [
    "quiet" "splash" "boot.shell_on_fail" "loglevel=3"
    "rd.systemd.show_status=false" "rd.udev.log_level=3" "udev.log_priority=3"
  ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
