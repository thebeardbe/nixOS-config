{ pkgs, ... }:
{
  imports = [
    ./packages.nix
  ];

  # Host-specific Hyprland Lua config (touchpad settings)
  home.file.".config/hypr/host.lua".source = ./hypr-host.lua;
}
