{ lib, ... }: {
  imports = [
    ./packages.nix
    ./monitors.nix
  ];

  # Smaller kitty font on the big ultrawide
  programs.kitty.font.size = lib.mkForce 9;
  programs.waybar.settings.mainBar.modules-right = lib.mkForce [
    "pulseaudio" "cpu" "memory" "tray" "custom/power"
  ];
}
