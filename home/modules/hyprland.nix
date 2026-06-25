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
    configType = "hyprlang";
    settings = {
      # --- Variables ---
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "wofi --show drun";
      "$fileManager" = "kitty -e yazi"; # Launch Yazi inside kitty

      # --- Monitor ---
      # "preferred, auto, 1" = best resolution, auto position, scale 1
      monitor = [
        ", preferred, auto, 1"
      ];

      # --- Autostart ---
      exec-once = [ 
        "nm-applet --indicator"  # NetworkManager tray icon
        "blueman-applet"         # Bluetooth tray icon
        "hyprpaper"              # Wallpaper daemon
        "bash -c 'hyprctl hyprpaper \"wallpaper ,/home/thebeardbe/Pictures/Wallpapers/solid-bg.png\" 2>/dev/null; sleep 1 && goto-workspace 1'"  # Solid bg then workspace
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
        # Disable the default Hyprland anime girl background and logo
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      # Default wallpaper — solid color to avoid the default Hyprland gradient
      wallpaper = ",/home/thebeardbe/Pictures/Wallpapers/solid-bg.png";

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
        "$mod, J, layoutmsg, togglesplit" # dwindle: toggle split direction
        "$mod, F, fullscreen,"

        # Move focus (Vim-style with arrow keys)
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Switch to workspace (Super + N) — also sets wallpaper
        "$mod, 1, exec, goto-workspace 1"
        "$mod, 2, exec, goto-workspace 2"
        "$mod, 3, exec, goto-workspace 3"
        "$mod, 4, exec, goto-workspace 4"
        "$mod, 5, exec, goto-workspace 5"
        "$mod, 6, exec, goto-workspace 6"
        "$mod, 7, exec, goto-workspace 7"
        "$mod, 8, exec, goto-workspace 8"
        "$mod, 9, exec, goto-workspace 9"
        "$mod, 0, exec, goto-workspace 10"

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

        # Power button
        ", XF86PowerOff, exec, wlogout"

        # Brightness control
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"

        # Lock screen (Super + L)
        "$mod, L, exec, hyprlock"

        # Pick wallpaper (Super + Shift + W)
        "$mod SHIFT, W, exec, pick-wallpaper"

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
  # Scripts for Hyprland (goto-workspace, pick-wallpaper)
  home.packages = with pkgs; [
    (pkgs.writeShellScriptBin "goto-workspace" ''
      WS="$1"
      WALLDIR="$HOME/Pictures/Wallpapers"
      STATE="$HOME/.cache/workspace-wallpapers"
      mkdir -p "$(dirname "$STATE")"
      [[ -f "$STATE" ]] || echo "{}" > "$STATE"

      WP=$(jq -r --arg w "$WS" '.[$w] // empty' < "$STATE")
      if [[ -z "$WP" || ! -f "$WP" ]]; then
        WP=$(find "$WALLDIR" -maxdepth 1 \( -name "solid-bg.png" -prune -o -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) \) | sort -R | head -1)
        if [[ -n "$WP" ]]; then
          tmp=$(mktemp)
          jq --arg w "$WS" --arg p "$WP" '. + {($w): $p}' < "$STATE" > "$tmp"
          mv "$tmp" "$STATE"
        fi
      fi

      # Set wallpaper synchronously (fast socket write, no delay)
      [[ -n "$WP" ]] && hyprctl hyprpaper "wallpaper ,$WP" &>/dev/null

      hyprctl dispatch workspace "$WS"
    '')

    # Wallpaper picker — saves choice for current workspace
    (pkgs.writeShellScriptBin "pick-wallpaper" ''
      WALL="$HOME/Pictures/Wallpapers"
      STATE="$HOME/.cache/workspace-wallpapers"
      mkdir -p "$(dirname "$STATE")"
      [[ -f "$STATE" ]] || echo "{}" > "$STATE"

      NAME=$(find "$WALL" -maxdepth 1 \( -name "solid-bg.png" -prune -o -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) \) | sort | sed 's|^.*/otherland-||; s|\.[^.]*$||; s|-| |g' | wofi --dmenu --prompt "Wallpaper")

      [[ -z "$NAME" ]] && exit 0

      FILE="otherland-$(echo "$NAME" | sed 's| |-|g')"
      for ext in jpg jpeg png; do
        W="$WALL/$FILE.$ext"
        if [[ -f "$W" ]]; then
          hyprctl hyprpaper "wallpaper ,$W"
          WS=$(hyprctl activeworkspace | grep -oP 'workspace ID \K\d+')
          tmp=$(mktemp)
          jq --arg w "$WS" --arg p "$W" '. + {($w): $p}' < "$STATE" > "$tmp"
          mv "$tmp" "$STATE"
          notify-send "Wallpaper" "$NAME"
          exit 0
        fi
      done
    '')
  ];
  
  # Deploy hyprpaper config from the modules directory
  xdg.configFile."hypr/hyprpaper.conf".source = ./hyprpaper.conf;
}
