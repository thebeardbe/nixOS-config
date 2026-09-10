{ config, pkgs, ... }:

{
  # Docker
  virtualisation.docker.enable = true;

  # Flatpak
  services.flatpak.enable = true;
}
