{ config, pkgs, lib, theme, ... }:

with lib;

{
  # Hyprland is enabled system-wide via programs.hyprland in common/configuration.nix.
  # We do NOT use home-manager's hyprland module because:
  # 1. We deploy our own Lua config via home.file (not hyprlang)
  # 2. Systemd activation is handled in the Lua autostart block (hl.on("hyprland.start"))
  # 3. greetd launches Hyprland with -c pointing to our Lua file
  #
  # We DO need hyprland-session.target for systemd-based services (waybar, hypridle, etc.)
  # to bind to. This is normally created by the home-manager hyprland module.
  wayland.systemd.target = "hyprland-session.target";
  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "Hyprland compositor session";
      Documentation = [ "man:systemd.special(7)" ];
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  # Scripts for Hyprland (goto-workspace, pick-wallpaper)
  home.packages = with pkgs; [
    luajit

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

      # Dispatch workspace in Lua-compatible format (double quotes for bash var expansion)
      hyprctl dispatch "hl.dsp.focus({ workspace = ''${WS} })"
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

    # Lock screen — shows hyprlock (if not already running)
    (pkgs.writeShellScriptBin "lock-screen" ''
      pidof hyprlock || hyprlock
    '')
  ];

  # Deploy hyprpaper config from the modules directory
  xdg.configFile."hypr/hyprpaper.conf".source = ./hyprpaper.conf;
}
