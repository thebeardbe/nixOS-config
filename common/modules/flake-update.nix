{ config, lib, pkgs, ... }:

{
  # Weekly flake update runs from exactly ONE host — the machine that owns the
  # shared flake.lock and is allowed to update it.
  # Leave this false on every other host to avoid concurrent lock updates.
  options.mySystem.flakeUpdate.enable = lib.mkEnableOption
    "the weekly flake update check (enable on exactly one host, the machine that owns the lock update)";

  # Weekly flake update CHECK (Monday 4am, randomized).
  #
  # This deliberately does NOT run `nixos-rebuild switch`. An input bump can
  # change the kernel and the NVIDIA driver, and a kernel/driver change only
  # takes effect after a reboot: until then the loaded module and the installed
  # userspace disagree, which breaks NVML (`nvidia-smi`), the CDI generator and
  # therefore every GPU container, plus newly started GPU apps. Applying that
  # unattended at 4am meant a broken GPU until the next reboot.
  #
  # So: update the lock, build the system, and tell the user it is ready. The
  # switch happens when they run `rebuild`. The notification and the marker file
  # both say whether the pending update needs a reboot.
  config.systemd.services.nix-flake-update = lib.mkIf config.mySystem.flakeUpdate.enable {
    description = "Check for Nix flake updates and stage a build";
    path = [ pkgs.git ];  # nix needs git on PATH for git+file flake lock updates
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/thebeardbe/nixOS-config";
    };
    script = ''
      set -uo pipefail
      REPO=/home/thebeardbe/nixOS-config
      MARKER=/home/thebeardbe/.cache/nixos-update-available
      HOST=$(${pkgs.coreutils}/bin/cat /etc/hostname)

      # Anything touching the repo or the user's session runs as thebeardbe so
      # file ownership and the session bus stay correct.
      runbe() {
        ${pkgs.util-linux}/bin/runuser -u thebeardbe -- \
          ${pkgs.coreutils}/bin/env HOME=/home/thebeardbe DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "$@"
      }
      notify() {
        runbe ${pkgs.libnotify}/bin/notify-send "$@" 2>/dev/null \
          || echo "notify-send failed (no session?)" >&2
      }

      cd "$REPO" || exit 1

      if ! runbe ${pkgs.nix}/bin/nix flake update; then
        notify -u critical "NixOS update check" "flake update failed, see journalctl -u nix-flake-update"
        exit 1
      fi

      # Commit the new lock as thebeardbe so the tree is never left dirty.
      # `git diff --quiet` exits non-zero only when flake.lock really changed,
      # and the pathspec commit records that one path alone. No push: the change
      # is local, and `rebuild` picks it up whenever the user runs it.
      if ! runbe ${pkgs.git}/bin/git diff --quiet -- flake.lock; then
        runbe ${pkgs.git}/bin/git commit -m "chore: weekly flake update" -- flake.lock \
          || echo "warning: flake.lock commit failed; continuing" >&2
      fi

      # Build only. Never switch: the user decides when the system changes.
      # HOME=/root + SUDO_UID make nix's git fetcher accept the
      # thebeardbe-owned repo (same mechanism as a real sudo invocation).
      if ! ${pkgs.coreutils}/bin/env HOME=/root SUDO_UID=1000 \
             ${pkgs.nixos-rebuild}/bin/nixos-rebuild build --flake "$REPO#$HOST" >/dev/null 2>&1; then
        notify -u critical "NixOS update check" "build failed, see journalctl -u nix-flake-update"
        exit 1
      fi

      NEW=$(${pkgs.coreutils}/bin/readlink -f "$REPO/result")
      CUR=$(${pkgs.coreutils}/bin/readlink -f /run/current-system)

      if [ -z "$NEW" ] || [ "$NEW" = "$CUR" ]; then
        # Nothing to do: clear any stale marker from a previous week.
        runbe ${pkgs.coreutils}/bin/sh -c "rm -f '$MARKER'"
        exit 0
      fi

      # Compare against the BOOTED system, not the current one: only the booted
      # kernel and driver are actually loaded, so that is what a reboot changes.
      BOOTED=$(${pkgs.coreutils}/bin/readlink -f /run/booted-system)
      kcur=$(${pkgs.coreutils}/bin/readlink -f "$BOOTED/kernel" 2>/dev/null || true)
      knew=$(${pkgs.coreutils}/bin/readlink -f "$NEW/kernel" 2>/dev/null || true)
      ncur=$(${pkgs.coreutils}/bin/readlink -f "$BOOTED/sw/lib/libnvidia-ml.so.1" 2>/dev/null || true)
      nnew=$(${pkgs.coreutils}/bin/readlink -f "$NEW/sw/lib/libnvidia-ml.so.1" 2>/dev/null || true)

      reboot=no
      why=""
      [ -n "$knew" ] && [ "$kcur" != "$knew" ] && { reboot=yes; why="kernel"; }
      [ -n "$nnew" ] && [ "$ncur" != "$nnew" ] && {
        reboot=yes
        why="''${why:+$why + }NVIDIA driver"
      }

      {
        echo "An updated system is built and staged, but NOT activated."
        echo ""
        echo "Built:   $NEW"
        echo "Running: $CUR"
        echo ""
        if [ "$reboot" = yes ]; then
          echo "This update changes the $why."
          echo "It only takes effect after a reboot; until then nvidia-smi, the"
          echo "CDI generator and GPU containers fail with a driver/library"
          echo "mismatch. Apply when you can reboot: run  rebuild  then reboot."
        else
          echo "No kernel or driver change: running  rebuild  is enough, no reboot needed."
        fi
      } > /tmp/nixos-update-marker

      runbe ${pkgs.coreutils}/bin/sh -c \
        "mkdir -p '$(${pkgs.coreutils}/bin/dirname "$MARKER")' && cat /tmp/nixos-update-marker > '$MARKER'"

      if [ "$reboot" = yes ]; then
        notify -u normal "NixOS update ready (needs reboot)" \
          "Includes a $why change. Run 'rebuild', then reboot. See 'os-update-status'."
      else
        notify -u normal "NixOS update ready" \
          "No reboot needed. Run 'rebuild' when convenient. See 'os-update-status'."
      fi
      exit 0
    '';
  };
  config.systemd.timers.nix-flake-update = lib.mkIf config.mySystem.flakeUpdate.enable {
    description = "Weekly Nix flake update check timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon 04:00";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };
}
