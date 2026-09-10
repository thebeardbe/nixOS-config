{ config, pkgs, ... }:

{
  # Use dbus-broker (GNOME default, avoids switch inhibitor warning)
  services.dbus.implementation = "broker";

  # Let Hyprland handle the power key instead of systemd
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # Make Hyprland available system-wide (needed for greetd to launch it)
  # The actual theming/binds are configured in home/files/hyprland.lua
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # environment settings
  environment.sessionVariables = {
     # If cursor becomes invisible
     WLR_NO_HARDWARE_CURSORS = "1";

     # Hint electron apps to use wayland
     NIXOS_OZONE_WL = "1";
  };
}
