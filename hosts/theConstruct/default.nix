{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common/configuration.nix
  ];

  networking.hostName = "theConstruct";

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };
}
