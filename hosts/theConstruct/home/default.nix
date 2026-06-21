{ ... }: {
  imports = [
    ./gaming.nix
  ];

  # Override shared waybar module list — no bluetooth, battery, backlight
  programs.waybar.settings.mainBar.modules-right = [
    "pulseaudio" "cpu" "memory" "tray" "custom/power"
  ];
}
