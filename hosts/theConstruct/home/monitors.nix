{ lib, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings = {
    monitor = lib.mkForce [
      "DP-2, 1920x1080@165, 0x0, 1"
      "DP-1, 3440x1440@60, -760x-1440, 1"
    ];

    workspace = [
      "1, monitor:DP-2"
      "2, monitor:DP-2"
      "3, monitor:DP-2"
      "4, monitor:DP-2"
      "5, monitor:DP-2"
      "6, monitor:DP-2"
      "7, monitor:DP-2"
      "8, monitor:DP-1"
      "9, monitor:DP-1"
      "10, monitor:DP-1"
    ];
  };
}
