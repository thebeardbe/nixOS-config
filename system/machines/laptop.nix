# Laptop: foxyNix (current machine)
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-gen.nix
    ./configuration.nix
  ];

  networking.hostName = "foxyNix";
}
