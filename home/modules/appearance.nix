{ pkgs, theme, ... }:

{
  # 1. GTK Apps (Gnome-stijl apps, Firefox, etc.)
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark"; # De standaard donkere look
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;

    gtk4.theme = null;
  };

  # 2. Qt Apps (OBS, VLC, etc.) - Zorg dat ze de GTK-stijl overnemen
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  # 3. Omgevingsvariabelen voor "Dark First"
  home.sessionVariables = {
    GTK_THEME = "Adwaita-dark";
    COLORTERM = "truecolor";
    # Forceert veel moderne apps (zoals LibAdwaita) naar dark mode
    ADW_DISABLE_PORTAL = "0"; 
  };

  # 4. Cursor (Consistentie is key)
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };
}
