{ config, lib, pkgs, ... }:

{
  # Weekly flake update runs from exactly ONE host — the machine that owns the
  # shared flake.lock and is allowed to update it.
  # Leave this false on every other host to avoid concurrent lock updates.
  options.mySystem.flakeUpdate.enable = lib.mkEnableOption
    "the weekly flake update check (enable on exactly one host, the machine that owns the lock update)";

  # Weekly flake update (Monday 4am, randomized).
  #
  # Normal package updates are applied automatically, as before. The exception
  # is any update that changes the KERNEL or the NVIDIA DRIVER: those only take
  # effect after a reboot, and until then the loaded module and the installed
  # userspace disagree, which breaks NVML (`nvidia-smi`), the CDI generator and
  # therefore every GPU container, plus newly started GPU apps. Applying that
  # unattended at 4am meant a silently broken GPU until the next reboot.
  #
  # So the rule is: if the newly built system uses the same kernel and the same
  # libnvidia-ml as the BOOTED system (the only copy actually loaded), switch
  # now. Otherwise never switch: make the new generation the BOOT DEFAULT with
  # `nixos-rebuild boot`, so the running system stays perfectly consistent and a
  # plain reboot applies the kernel and the driver at once. The user reboots
  # when it suits them.
  config.systemd.services.nix-flake-update = lib.mkIf config.mySystem.flakeUpdate.enable {
    description = "Update Nix flake inputs and apply or stage the build";
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
      # nix/repos are root-owned from a service; HOME=/root and SUDO_UID make
      # nix's git fetcher accept the thebeardbe-owned repo (the mechanism a real
      # sudo invocation uses).
      rebuild() {
        ${pkgs.coreutils}/bin/env HOME=/root SUDO_UID=1000 \
          ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@" --flake "$REPO#$HOST"
      }

      cd "$REPO" || exit 1

      if ! runbe ${pkgs.nix}/bin/nix flake update; then
        notify -u critical "NixOS update" "flake update failed, see journalctl -u nix-flake-update"
        exit 1
      fi

      # Commit the new lock as thebeardbe so the tree is never left dirty.
      # `git diff --quiet` exits non-zero only when flake.lock really changed,
      # and the pathspec commit records that one path alone. No push: the change
      # is local and `rebuild` / this service picks it up.
      if ! runbe ${pkgs.git}/bin/git diff --quiet -- flake.lock; then
        runbe ${pkgs.git}/bin/git commit -m "chore: weekly flake update" -- flake.lock \
          || echo "warning: flake.lock commit failed; continuing" >&2
      fi

      if ! rebuild build >/dev/null 2>&1; then
        notify -u critical "NixOS update" "build failed, see journalctl -u nix-flake-update"
        exit 1
      fi

      NEW=$(${pkgs.coreutils}/bin/readlink -f "$REPO/result")
      CUR=$(${pkgs.coreutils}/bin/readlink -f /run/current-system)
      BOOTED=$(${pkgs.coreutils}/bin/readlink -f /run/booted-system)

      if [ -z "$NEW" ] || { [ "$NEW" = "$CUR" ] && [ "$CUR" = "$BOOTED" ]; }; then
        # Nothing to do: clear any stale marker from a previous week.
        runbe ${pkgs.coreutils}/bin/sh -c "rm -f '$MARKER'"
        exit 0
      fi

      # Compare against the BOOTED system: only its kernel and driver are
      # actually loaded, so only a difference there needs a reboot.
      kboot=$(${pkgs.coreutils}/bin/readlink -f "$BOOTED/kernel" 2>/dev/null || true)
      knew=$(${pkgs.coreutils}/bin/readlink -f "$NEW/kernel" 2>/dev/null || true)
      nboot=$(${pkgs.coreutils}/bin/readlink -f "$BOOTED/sw/lib/libnvidia-ml.so.1" 2>/dev/null || true)
      nnew=$(${pkgs.coreutils}/bin/readlink -f "$NEW/sw/lib/libnvidia-ml.so.1" 2>/dev/null || true)

      reboot=no
      why=""
      if [ -n "$knew" ] && [ "$kboot" != "$knew" ]; then
        reboot=yes
        why="kernel"
      fi
      if [ -n "$nnew" ] && [ "$nboot" != "$nnew" ]; then
        reboot=yes
        why="''${why:+$why + }NVIDIA driver"
      fi

      if [ "$reboot" = no ]; then
        # Same kernel and driver as the running system: nothing here needs a
        # reboot, so apply it now like the timer always used to.
        if rebuild switch >/dev/null 2>&1; then
          runbe ${pkgs.coreutils}/bin/sh -c "rm -f '$MARKER'"
          notify "NixOS updated" "Applied automatically (no reboot needed)."
          exit 0
        fi
        notify -u critical "NixOS update" "automatic switch failed, see journalctl -u nix-flake-update"
        exit 1
      fi

      # Kernel or driver change: never switch. Activating the new userspace while
      # the old module is still loaded leaves the GPU broken until the reboot, so
      # make the new generation the boot default instead and let the reboot apply
      # both halves at once.
      if ! rebuild boot >/dev/null 2>&1; then
        notify -u critical "NixOS update" "staging the update failed, see journalctl -u nix-flake-update"
        exit 1
      fi

      {
        echo "An updated system is staged as the BOOT DEFAULT. Nothing was activated."
        echo ""
        echo "Staged:  $NEW"
        echo "Running: $CUR"
        echo ""
        echo "This update changes the $why."
        echo ""
        echo "Reboot when convenient. Nothing broken runs in the meantime: the"
        echo "running system keeps its matching kernel and userspace, and the"
        echo "reboot applies both at once."
        echo ""
        echo "After the reboot, check with:  nvidia-smi -L"
      } > /tmp/nixos-update-marker

      runbe ${pkgs.coreutils}/bin/sh -c \
        "mkdir -p '$(${pkgs.coreutils}/bin/dirname "$MARKER")' && cat /tmp/nixos-update-marker > '$MARKER'"

      notify -u normal "NixOS update staged (reboot when convenient)" \
        "Includes a $why change. Set as the boot default; reboot when you like. See 'os-update-status'."
      exit 0
    '';
  };
  config.systemd.timers.nix-flake-update = lib.mkIf config.mySystem.flakeUpdate.enable {
    description = "Weekly Nix flake update timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon 04:00";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };
}
