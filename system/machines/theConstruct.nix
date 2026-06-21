# The Construct: AMD Ryzen 5600 + NVIDIA RTX 3060 Ti
{ config, pkgs, ... }:

{
  imports = [
    ./hardware/theConstruct.nix
    ./configuration.nix
  ];

  networking.hostName = "theConstruct";

  # Steam (with XWayland support via Hyprland's xwayland.enable = true)
  programs.steam = {
    enable = true;
    gamescope.enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };
}
