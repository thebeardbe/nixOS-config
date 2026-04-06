{ pkgs, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # --- Variabelen ---
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "wofi --show drun";
      "$fileManager" = "kitty -e yazi"; # Start Yazi direct in een terminal
      # --- Monitor Config ---
      # "preferred, auto, 1" kiest de beste resolutie en zet hem op de juiste plek.
      monitor = ", preferred, auto, 1";
      exec-once = [ 
	"nm-applet --indicator" # Wifi icon in waybar
      ];
      
      # --- Look & Feel ---
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        layout = "dwindle";
        allow_tearing = false;
      };

      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
      };

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
#          "bordercycle, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      # --- Window Management Binds ---
      bind = [
        # Basis acties
        "$mod, Q, exec, $terminal"
        "$mod, C, killactive,"
        "$mod, M, exit,"
        "$mod, E, exec, $fileManager"
        "$mod, V, togglefloating,"
        "$mod, space, exec, $menu"
        "$mod, P, pseudo," # dwindle
        "$mod, J, togglesplit," # dwindle
        "$mod, F, fullscreen,"

        # Focus verplaatsen (Vim-stijl of pijltjes)
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Switchen tussen workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"

        # Window verplaatsen naar workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"

        # Screenshots (met hyprshot)
        ", Print, exec, hyprshot -m output"
        "$mod, Print, exec, hyprshot -m window"

	# Volume regeling
        ", XF86AudioRaiseVolume, exec, pamixer -i 5"
        ", XF86AudioLowerVolume, exec, pamixer -d 5"
        ", XF86AudioMute, exec, pamixer -t"
      ];

      # Muis acties (vasthouden om te verplaatsen/resizen)
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # De ondersteunende tools voor de Hypr-ervaring
  home.packages = with pkgs; [
    yazi         # De ster van de show
    ffmpegthumbnailer # Voor video previews in Yazi
    jq           # Voor JSON previews
    poppler      # Voor PDF previews
    fd           # Snellere search voor Yazi
    ripgrep      # Snellere content search
    fzf          # Fuzzy finder integratie

    hyprpaper    # Wallpaper
    hyprlock     # Lockscreen
    hypridle     # Auto-sleep
    hyprshot     # Screenshot tool
    waybar       # De statusbalk bovenaan
    wofi         # De applicatie launcher
    kitty        # Je terminal
    libnotify    # Voor notificaties
    swaynotificationcenter # Notificatie paneel
  ];
}
