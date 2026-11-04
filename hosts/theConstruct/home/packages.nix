{ pkgs, ... }: {
  home.packages = with pkgs; [
    steam-run
    mangohud
    prismlauncher
    heroic
    p7zip
    # Sets the XWayland primary monitor at session start (see hypr-host.lua)
    xrandr

    # Wine / Proton game management (Battle.net via Steam + Proton)
    protonup-qt            # Install/manage GE-Proton builds
    protontricks           # Winetricks wrapper for individual Proton prefixes

    # Music production (desk-bound: paired with the Akai MPD218)
    ardour                 # DAW (binary is `ardour9`)
    hydrogen               # Drum machine / sequencer

    # Manage the local llama.cpp compose stack (~/.config/llama/compose.yaml).
    # Host-scoped: the GPU, the models and the compose file only exist here.
    # The stack has no systemd unit and restart: "no", so this is the only way
    # it changes state. `up` is idempotent: it creates the container the first
    # time and starts it afterwards.
    (writeShellScriptBin "llama" ''
      set -euo pipefail
      compose="$HOME/.config/llama/compose.yaml"
      if [ ! -f "$compose" ]; then
        echo "llama: missing $compose (rebuild the config first)" >&2
        exit 1
      fi

      cmd="''${1:-status}"
      [ $# -gt 0 ] && shift

      case "$cmd" in
        up|start)
          exec ${docker}/bin/docker compose -f "$compose" up --detach
          ;;
        stop)
          exec ${docker}/bin/docker compose -f "$compose" stop
          ;;
        down)
          # Removes the container as well; `stop` keeps it for a fast restart.
          exec ${docker}/bin/docker compose -f "$compose" down
          ;;
        restart)
          exec ${docker}/bin/docker compose -f "$compose" restart
          ;;
        status|ps)
          exec ${docker}/bin/docker compose -f "$compose" ps
          ;;
        logs)
          exec ${docker}/bin/docker compose -f "$compose" logs --follow "$@"
          ;;
        help|-h|--help)
          cat <<'EOF'
llama - manage the local llama.cpp stack on this host

Usage: llama <command>

Commands:
  up        Start the stack. Creates the container the first time, starts it after.
  stop      Stop it, keeping the container so the next start is instant.
  down      Stop and remove the container entirely.
  restart   Restart the running container.
  status    Show container state and health (default when no command is given).
  logs      Follow the server log. Ctrl-C stops following, not the server.
  help      Show this help.

Notes:
  - There is no systemd unit and the restart policy is "no", so nothing starts
    it at boot, and it stays stopped once stopped.
  - Any nixos-rebuild that restarts docker.service stops it. Run `llama up` after
    a rebuild (or after a reboot) to bring it back.
  - The tailnet exposure is a separate unit, not part of the stack:
      systemctl status tailscale-serve-llama
  - Compose file: ~/.config/llama/compose.yaml (deployed from the nix repo)
  - Models live in /mnt/the-grail/llama-models (mounted at /models)
EOF
          exit 0
          ;;
        *)
          echo "usage: llama up | stop | down | restart | status | logs | help" >&2
          echo "       run 'llama help' for details" >&2
          exit 1
          ;;
      esac
    '')

    # Streaming / recording (Wayland capture via xdg-desktop-portal-hyprland)
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        obs-vkcapture                # Game Capture (Vulkan/OpenGL)
        obs-pipewire-audio-capture   # Per-application audio capture
        obs-backgroundremoval        # AI background removal
        distroav                     # NDI support
        obs-source-record            # Source Record filter
        advanced-scene-switcher      # Auto scene switcher module

        # "Move source" filters used by several scenes. OBS 32.2 deprecated
        # obs_properties_add_button, which trips this plugin's own
        # CMAKE_COMPILE_WARNING_AS_ERROR=ON default and fails the build.
        # Turning that flag off is the minimal fix.
        (obs-move-transition.overrideAttrs (old: {
          cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DCMAKE_COMPILE_WARNING_AS_ERROR=OFF" ];
        }))
      ];
    })
  ];
}
