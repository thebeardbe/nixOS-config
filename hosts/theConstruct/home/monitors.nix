{ lib, pkgs, ... }:

{
  wayland.windowManager.hyprland.settings.monitor = lib.mkForce [
    # Main: AOC 27" 165Hz (bottom)
    "DP-2, 1920x1080@165, 0x0, 1"
    # Ultrawide: LG 3440x1440 (above main, centered)
    "DP-1, 3440x1440@60, -760x-1440, 1"
  ];
}
