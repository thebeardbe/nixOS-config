{ config, pkgs, lib, theme, ... }:

with lib;

{
  wayland.windowManager.hyprland = {
    enable = true;
    # Module generates hypr/hyprland.conf (hyprlang, just systemd activation).
    # The main Hyprland config is in Lua at ~/.config/hypr/hyprland.lua
    # loaded via greetd's -c flag in common/configuration.nix
    # Host-specific overrides in ~/.config/hypr/host.lua (loaded by hyprland.lua)
    settings = { };
  };

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
  ];

  # Deploy hyprpaper config from the modules directory
  xdg.configFile."hypr/hyprpaper.conf".source = ./hyprpaper.conf;
}
