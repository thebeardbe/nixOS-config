{ config, pkgs, ... }:

{
  # GNOME portal provides org.freedesktop.portal.Background (needed by Packet's
  # "run in background" mode). Only Background is routed to it — everything else
  # keeps using the gtk/hyprland portals.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  xdg.portal.config.common = {
    "org.freedesktop.impl.portal.Background" = "gnome";
    "org.freedesktop.impl.portal.Screenshot" = "hyprland";
    "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
    "org.freedesktop.impl.portal.GlobalShortcuts" = "hyprland";
    "org.freedesktop.impl.portal.RemoteDesktop" = "hyprland";
  };
  # The GNOME portal segfaults on resume (libgtk-4). Auto-restart it so
  # Packet's background mode recovers without a manual restart.
  systemd.user.services."xdg-desktop-portal-gnome" = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "2";
    };
  };
}
