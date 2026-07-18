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

  # Scripts for Hyprland: workspace wallpaper + wallpaper picker
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

    # Fix JBL Quantum headset — reinitialize USB audio without reboot
    (pkgs.writeShellScriptBin "fix-jbl" ''
      CARD="alsa_card.usb-JBL_JBL_Quantum_360X_Wireless-00"
      PROFILE="output:analog-stereo+input:mono-fallback"

      # Step 1: Toggle profile to reinitialize ALSA (always restores working profile)
      echo "→ Reinitializing JBL headset..."
      pactl set-card-profile "$CARD" off 2>/dev/null
      sleep 1
      pactl set-card-profile "$CARD" "$PROFILE" 2>/dev/null

      # Step 2: If no sink appeared, restart PipeWire
      if ! pactl list sinks 2>/dev/null | grep -q "JBL"; then
        echo "→ Restarting PipeWire..."
        systemctl --user restart pipewire pipewire-pulse 2>/dev/null
        sleep 2
      fi

      # Step 3: USB reset as last resort (needs sudo)
      if ! pactl list sinks 2>/dev/null | grep -q "JBL"; then
        USB_PATH="/sys/bus/usb/devices/3-1.3"
        if [ -d "$USB_PATH" ]; then
          echo "→ Resetting USB device..."
          echo 0 | sudo tee "$USB_PATH/authorized" >/dev/null 2>&1
          sleep 1
          echo 1 | sudo tee "$USB_PATH/authorized" >/dev/null 2>&1
          sleep 2
          # Always restore profile after USB reset
          pactl set-card-profile "$CARD" "$PROFILE" 2>/dev/null
        fi
      fi

      # Report result
      if pactl list sinks 2>/dev/null | grep -q "JBL"; then
        echo "✅ JBL headset is working!"
      else
        echo "❌ Could not fix JBL headset. Try unplugging and re-plugging the USB dongle."
      fi
    '')
  ];

  # Deploy hyprpaper config from the modules directory
  xdg.configFile."hypr/hyprpaper.conf".source = ./hyprpaper.conf;
}
