{ lib, ... }: {
  imports = [
    ./packages.nix
    ./monitors.nix
  ];

  # Smaller GTK font for the ultrawide (affects Firefox UI, etc.)
  gtk.font = lib.mkForce {
    name = "FiraCode Nerd Font";
    size = 10;
  };

  # Smaller kitty font on the big ultrawide
  programs.kitty.font.size = lib.mkForce 9;
  programs.waybar.settings.mainBar.modules-right = lib.mkForce [
    "pulseaudio" "cpu" "memory" "tray" "custom/notification" "custom/power"
  ];
}
