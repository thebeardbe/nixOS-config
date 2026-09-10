{ config, lib, pkgs, ... }:

{
  # Weekly flake update runs from exactly ONE host — the machine that owns the
  # shared flake.lock and is allowed to rebuild itself after updating it.
  # Leave this false on every other host to avoid concurrent lock updates.
  options.mySystem.flakeUpdate.enable = lib.mkEnableOption
    "the weekly flake update timer and rebuild service (enable on exactly one host, the machine that owns the lock update)";

  # Weekly flake update + rebuild (Monday 4am, randomized).
  # Updates the shared flake.lock as thebeardbe (keeps git ownership sane),
  # then rebuilds the CURRENT host (flake attr = hostname). Output lands in
  # journald automatically — no logger pipes needed.
  config.systemd.services.nix-flake-update = lib.mkIf config.mySystem.flakeUpdate.enable {
    description = "Update Nix flake inputs and rebuild";
    path = [ pkgs.git ];  # nix needs git on PATH for git+file flake lock updates
    serviceConfig = {
      Type = "oneshot";
      WorkingDirectory = "/home/thebeardbe/nixOS-config";
    };
    script = ''
      cd /home/thebeardbe/nixOS-config
      # flake.lock update as thebeardbe (keeps file ownership sane for git)
      ${pkgs.util-linux}/bin/runuser -u thebeardbe -- ${pkgs.coreutils}/bin/env HOME=/home/thebeardbe ${pkgs.nix}/bin/nix flake update
      # Commit the new lock as thebeardbe so the tree is never left dirty.
      # `git diff --quiet` exits non-zero only when flake.lock really changed, and
      # the pathspec commit records that one path alone, leaving any other staged
      # work untouched. No push: the change is local, the rebuild picks it up.
      if ! ${pkgs.util-linux}/bin/runuser -u thebeardbe -- ${pkgs.coreutils}/bin/env HOME=/home/thebeardbe ${pkgs.git}/bin/git diff --quiet -- flake.lock; then
        ${pkgs.util-linux}/bin/runuser -u thebeardbe -- ${pkgs.coreutils}/bin/env HOME=/home/thebeardbe ${pkgs.git}/bin/git commit -m "chore: weekly flake update" -- flake.lock \
          || echo "warning: flake.lock commit failed; continuing with rebuild" >&2
      fi
      # rebuild as root with root's HOME (libgit2 repo-ownership check);
      # SUDO_UID makes nix's git fetcher accept thebeardbe-owned repo (same
      # mechanism as a real sudo invocation)
      ${pkgs.coreutils}/bin/env HOME=/root SUDO_UID=1000 ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake /home/thebeardbe/nixOS-config#$(${pkgs.coreutils}/bin/cat /etc/hostname)
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
