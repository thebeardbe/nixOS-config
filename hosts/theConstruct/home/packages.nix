{ pkgs, ... }: {
  home.packages = with pkgs; [
    steam-run
    mangohud
    prismlauncher
    heroic
    p7zip
    # Sets the XWayland primary monitor at session start (see hypr-host.lua)
    xrandr
  ];
}
