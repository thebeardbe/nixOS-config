# Laptop: foxyNix
{ config, pkgs, ... }:

{
  imports = [
    ../hardware/laptop.nix
    ../configuration.nix
  ];

  networking.hostName = "foxyNix";
}
