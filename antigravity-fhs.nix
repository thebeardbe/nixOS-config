{ pkgs ? import <nixpkgs> {} }:

pkgs.buildFHSEnv {
  name = "antigravity-fhs";
  targetPkgs = pkgs: with pkgs; [
    playwright-driver.browsers
    glib
    expat
    libxshmfence
    libGL
    mesa
    nss
    nspr
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    gdk-pixbuf
    gtk3
    pango
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXrender
    xorg.libXScrnSaver
    xorg.libXtst
  ];
  runScript = "antigravity";
}
