{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common/configuration.nix
  ];

  networking.hostName = "foxyNix";
}
