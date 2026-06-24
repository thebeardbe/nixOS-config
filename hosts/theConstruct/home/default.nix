{ lib, ... }: {
  imports = [
    ./packages.nix
  ];

  # Override shared waybar module list — no bluetooth, battery, backlight
  programs.waybar.settings.mainBar.modules-right = lib.mkForce [
    "pulseaudio" "cpu" "memory" "tray" "custom/power"
  ];
}
