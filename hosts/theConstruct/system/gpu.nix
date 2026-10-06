{ config, lib, pkgs, ... }:

{
  # NVIDIA RTX 3060 Ti
  services.xserver.videoDrivers = [ "nvidia" ];

  environment.systemPackages = with pkgs; [
    nvidia-vaapi-driver  # Hardware video decode for Steam/Chromium
  ];

  hardware.nvidia = {
    modesetting.enable = true;
    # Adds the nvidia-suspend / nvidia-resume / nvidia-hibernate services and
    # NVreg_PreserveVideoMemoryAllocations=1. Without it the driver throws
    # "NVRM: Xid 13 ... Graphics Exception" in clients on resume, which killed
    # hyprlock while it held the session lock (2026-09-19 14:13).
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Fix blank screen on boot
  boot.kernelParams = [ "nvidia_drm.modeset=1" ];
  boot.initrd.kernelModules = [ "nvidia" ];
  hardware.graphics.enable32Bit = true;
}
