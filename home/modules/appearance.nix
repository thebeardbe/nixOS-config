{ pkgs, theme, ... }:

{
  # 1. GTK Theme (affects GTK3/GTK4 apps: Firefox, Nautilus, GNOME apps, etc.)
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark"; # Default dark GTK theme
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
    # Let GTK4 apps use their own libadwaita styling (Adwaita-dark via portal)
    gtk4.theme = null;
  };

  # 2. Qt Theme — make Qt apps (OBS, VLC, etc.) follow the GTK dark style
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };

  # 3. Environment variables enforcing dark mode everywhere
  home.sessionVariables = {
    GTK_THEME = "Adwaita-dark";
    COLORTERM = "truecolor";
    # Forces libadwaita apps (GNOME Settings, etc.) into dark mode
    ADW_DISABLE_PORTAL = "0"; 
  };

  # 4. Cursor theme — consistency across GTK and X11 apps
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # 5. Kitty (Terminal emulator) — themed via central theme.json
  programs.kitty = {
    enable = true;
    themeFile = "Cyberpunk-Neon";
    font = {
      name = theme.font.family;
      size = theme.font.size;
    };
    settings = {
      background_opacity = toString theme.opacity;
    };
  };

  # 6. Wofi (Application launcher) — themed via central theme.json
  programs.wofi = {
    enable = true;
    style = ''
      window {
        background-color: rgba(13, 13, 13, 0.85);
        color: ${theme.colors.text};
        font-family: "${theme.font.family}";
        font-size: 14px;
        border: 2px solid ${theme.colors.accent};
        border-radius: 10px;
        padding: 20px;
      }
      #inner-box {
        background-color: transparent;
      }
      #input {
        background-color: rgba(255, 255, 255, 0.1);
        color: ${theme.colors.accent};
        border: 1px solid ${theme.colors.border};
        margin-bottom: 15px;
        padding: 10px;
      }
      #entry {
        padding: 10px;
        border-radius: 5px;
      }
      #entry:selected {
        background-color: ${theme.colors.accent};
        color: white;
      }
    '';
  };

  # 7. Fuzzel (alternative launcher) — Super+Shift+Space
  xdg.configFile."fuzzel/fuzzel.ini" = {
    enable = true;
    text =
      let
        # Strip # prefix and append ff for full alpha (fuzzel uses RGBA hex)
        rgba = color: builtins.substring 1 6 color + "ff";
      in
      ''
        [main]
        font = ${theme.font.family}:size=${toString (theme.font.size - 2)}
        prompt = run:
        terminal = kitty
        icons-enabled = yes
        icon-theme = Papirus-Dark
        layer = overlay
        width = 35
        lines = 12
        horizontal-pad = 30
        vertical-pad = 8
        inner-pad = 4

        [colors]
        background = ${rgba theme.colors.background}
        text = ${rgba theme.colors.text}
        prompt = ${rgba theme.colors.accent}
        input = ${rgba theme.colors.text}
        match = ${rgba theme.colors.accent}
        selection = ${rgba theme.colors.accent}
        selection-text = ${rgba theme.colors.background}
        selection-match = ffffffff
        border = ${rgba theme.colors.border}

        [border]
        width = 2
        radius = 10
      '';
  };
}
