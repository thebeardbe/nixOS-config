# Desktop: AMD Ryzen 5600 + NVIDIA RTX 3060 Ti
{ config, pkgs, ... }:

{
  imports = [
    ./hardware/desktop.nix
    ./configuration.nix
  ];

  networking.hostName = "desktop";

  # Steam (with XWayland support via Hyprland's xwayland.enable = true)
  programs.steam = {
    enable = true;
    gamescope.enable = true;      # Gamescope for better gaming compositing
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Desktop monitors (adjust as needed)
  # This overrides the laptop monitor config in home-manager
}
