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

  # 5. Kitty (Terminal)
  programs.kitty = {
    enable = true;
    font = {
      name = theme.font.family;
      size = theme.font.size;
    };
    settings = {
      background = theme.colors.background;
      foreground = theme.colors.text;
      cursor = theme.colors.accent;
      selection_background = theme.colors.accent;
      selection_foreground = theme.colors.background;
      background_opacity = toString theme.opacity;
      
      # Basic colors using theme
      color0 = theme.colors.background;
      color1 = theme.colors.critical;
      color2 = theme.colors.accent;
      color3 = theme.colors.text; # Yellow-ish
      color4 = theme.colors.accent;
      color5 = theme.colors.accent;
      color6 = theme.colors.accent;
      color7 = theme.colors.text;
    };
  };

  # 6. Wofi (Launcher)
  programs.wofi = {
    enable = true;
    style = ''
      window {
        background-color: ${theme.colors.background};
        color: ${theme.colors.text};
        font-family: "${theme.font.family}";
        font-size: 14px;
        border: 2px solid ${theme.colors.accent};
        border-radius: 10px;
      }
      #inner-box {
        background-color: transparent;
      }
      #input {
        background-color: ${theme.colors.background};
        color: ${theme.colors.accent};
        border: 1px solid ${theme.colors.border};
        margin: 10px;
      }
      #entry:selected {
        background-color: ${theme.colors.accent};
        color: ${theme.colors.background};
      }
    '';
  };
}
