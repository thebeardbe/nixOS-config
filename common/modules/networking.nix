{ config, pkgs, ... }:

{
  services.resolved.enable = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable tailscale
  services.tailscale = {
    enable = true;
    # Don't accept routes from other nodes — avoids interfering with local LAN
    extraUpFlags = [ "--accept-routes=false" ];
  };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
}
