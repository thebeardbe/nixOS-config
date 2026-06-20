{ config, pkgs, lib, theme, ... }:

with lib;

let
  # Helper: strip the '#' from a hex color for Hyprland's 0xff format
  # e.g., "#0000FF" -> "0000FF" -> Hyprland uses "0xff0000FF"
  formatColor = color:
    let
      raw = removePrefix "#" color;
    in
      toUpper raw;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # --- Variables ---
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "wofi --show drun";
      "$fileManager" = "kitty -e yazi"; # Launch Yazi inside kitty

      # --- Monitor ---
      # "preferred, auto, 1" = best resolution, auto position, scale 1
      monitor = ", preferred, auto, 1";

      # --- Autostart ---
      exec-once = [ 
        "nm-applet --indicator"  # NetworkManager tray icon
        "blueman-applet"         # Bluetooth tray icon
        "hyprpaper"              # Wallpaper daemon
      ];
      
      # --- Environment Variables ---
      env = [
        "PLAYWRIGHT_BROWSERS_PATH=/home/thebeardbe/.nix-profile/lib/playwright"
        "HOME=/home/thebeardbe"
      ];

      # --- General Appearance ---
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "0xff${formatColor theme.colors.accent}";
        "col.inactive_border" = "0xaa${formatColor theme.colors.background}";
        layout = "dwindle";
        allow_tearing = false;
      };

      # --- Misc ---
      misc = {
        # Suppress the "not started with start-hyprland" warning when launched from greetd
        disable_watchdog_warning = true;
      };

      # --- Decorations ---
      decoration = {
        rounding = 10;

        # Window opacity levels
        active_opacity = 0.95;
        inactive_opacity = 0.75;
        fullscreen_opacity = 1.0;

        blur = {
          enabled = true;
          size = 3;
          passes = 1;
          xray = true; # Only blur visible content (performance optimization)
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
      };
      
      # --- Animations ---
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      # --- Keybinds ---
      bind = [
        # Basic actions
        "$mod, Q, exec, $terminal"
        "$mod, C, killactive,"
        "$mod, M, exit,"
        "$mod, E, exec, $fileManager"
        "$mod, V, togglefloating,"
        "$mod, space, exec, $menu"
        "$mod, P, pseudo,"      # dwindle: toggle pseudo-tiling
        "$mod, J, togglesplit," # dwindle: toggle split direction
        "$mod, F, fullscreen,"

        # Move focus (Vim-style with arrow keys)
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Switch to workspace (Super + N)
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 0"

        # Move window to workspace (Super + Shift + N)
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Screenshots
        ", Print, exec, hyprshot -m output"       # Full screen
        "$mod, Print, exec, hyprshot -m window"   # Active window

        # Volume control
        ", XF86AudioRaiseVolume, exec, pamixer -i 5"
        ", XF86AudioLowerVolume, exec, pamixer -d 5"
        ", XF86AudioMute, exec, pamixer -t"

        # Brightness control
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"

        # Lock screen (Super + L)
        "$mod, L, exec, hyprlock"

        # Reload Hyprland config (Super + Shift + R)
        # Reloads without closing any applications
        "$mod SHIFT, R, exec, hyprctl reload"
      ];

      # --- Mouse bindings ---
      # Hold Super and drag to move/resize windows
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # Supporting packages for the Hyprland ecosystem
  home.packages = with pkgs; [
    yazi                    # Terminal file manager (default file manager)
    ffmpegthumbnailer       # Video thumbnails in Yazi
    jq                      # JSON previews in Yazi
    poppler                 # PDF previews in Yazi
    fd                      # Fast file search for Yazi
    ripgrep                 # Fast content search for Yazi
    fzf                     # Fuzzy finder integration

    hyprlock                # Lockscreen
    hypridle                # Auto-sleep/idle daemon
    hyprshot                # Screenshot tool
    wofi                    # Application launcher
    kitty                   # Terminal emulator
    libnotify               # Notification daemon (notify-send)
    swaynotificationcenter  # Notification center UI
    hyprpaper               # Dynamic wallpaper manager
  ];
  
  # Deploy hyprpaper config from the modules directory
  xdg.configFile."hypr/hyprpaper.conf".source = ./hyprpaper.conf;
}
