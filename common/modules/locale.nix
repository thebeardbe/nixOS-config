{ config, pkgs, ... }:

{
  # Set your time zone.
  time.timeZone = "Europe/Brussels";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11 and wayland
  services.xserver.xkb = {
    layout = "us";
    variant = "altgr-intl";
  };

  # Configure keymap in console
  # us-acentos is the console equivalent of the X11 us/altgr-intl dead-key layout.
  console.keyMap = "us-acentos";
}
