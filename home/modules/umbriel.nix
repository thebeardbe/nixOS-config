# Umbriel, the trial compositor. Installed alongside Hyprland, not instead of it.
#
# Nothing here touches the Hyprland session: the same keybind set is mirrored in
# files/umbriel/config.toml, and `trial-umbriel` runs it NESTED inside the
# current desktop (WLR_BACKENDS=wayland), so a crash closes a window instead of
# ending the session. In nested mode Umbriel maps `Mod` to Alt, so the trial
# cannot collide with Hyprland's Super binds.
#
# Config is validated at build time with Umbriel's own validator: a syntax error
# in the keybinds fails the rebuild instead of silently dropping binds at
# runtime. Note that this build accepts colon-separated action arguments
# (`submap:resize`), while the published docs still show the older space form.
{ pkgs, ... }:

let
  validatedConfig = pkgs.runCommand "umbriel-config.toml" { } ''
    ${pkgs.umbriel}/bin/umbriel config validate -c ${../files/umbriel/config.toml}
    cp ${../files/umbriel/config.toml} $out
  '';

  trial-umbriel = pkgs.writeShellScriptBin "trial-umbriel" ''
    set -uo pipefail
    if [ -z "''${WAYLAND_DISPLAY:-}" ]; then
      echo "trial-umbriel: no WAYLAND_DISPLAY, start it from the graphical session" >&2
      exit 1
    fi
    log="''${XDG_STATE_HOME:-$HOME/.local/state}/umbriel-nested.log"
    mkdir -p "$(dirname "$log")"
    echo "=== trial $(date -Iseconds) ===" >> "$log"
    echo "nested Umbriel: Mod is Alt in here, Hyprland keeps Super. Log: $log"
    exec env WLR_BACKENDS=wayland ${pkgs.umbriel}/bin/umbriel "$@" 2>&1 | tee -a "$log"
  '';
in
{
  home.packages = [ pkgs.umbriel trial-umbriel ];

  # Umbriel never writes its own config, so a read-only store symlink is safe.
  # A rebuild changes the link target, and the running instance keeps its
  # in-memory config until it is restarted.
  home.file.".config/umbriel/config.toml".source = validatedConfig;
}
