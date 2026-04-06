{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mySystem.touchpad;
in {
  # We definiëren een 'optie' die we aan of uit kunnen zetten
  options.mySystem.touchpad = {
    enable = mkEnableOption "Enable custom touchpad settings";
  };

  # De configuratie wordt alleen toegepast als de optie op 'true' staat
  config = mkIf cfg.enable {
    services.libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        clickMethod = "clickfinger";
        tapping = true;
      };
    };
  };
}
