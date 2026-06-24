{ config, lib, pkgs, ... }:

{
  # NVIDIA RTX 3060 Ti
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
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
