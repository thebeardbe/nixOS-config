{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.mySystem.touchpad;
in {
  # Declare an option `mySystem.touchpad.enable` that can be toggled on/off
  # Used in configuration.nix: mySystem.touchpad.enable = true;
  options.mySystem.touchpad = {
    enable = mkEnableOption "Enable custom touchpad settings";
  };

  # Only apply these libinput settings if the option is enabled
  config = mkIf cfg.enable {
    services.libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;   # Two-finger scroll moves content (like macOS)
        clickMethod = "clickfinger"; # Two-finger tap = right-click, three = middle
        tapping = true;            # Tap to click
      };
    };
  };
}
