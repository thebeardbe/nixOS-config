{ config, pkgs, lib, ... }:

let
  # Retention policy in one place, so the numbers can be audited without reading
  # the script. Each kept generation is a whole system closure with Steam, OBS,
  # the kernel and the NVIDIA module tree, so the cap matters more than the dates.
  keepAllDays = 3;      # everything this recent
  keepWeekly = 4;       # then 1 per week for 4 weeks
  keepMonthly = 3;      # then 1 per month for 3 months
  maxGenerations = 10;  # hard cap, whatever the dates say
  minFreeGiB = 20;      # free-space floor the cleanup must restore
in
{
  # ── Nix Garbage Collection ────────────────────────────────────────────────
  # Removes unreachable store paths only. `nix.gc.options` defaults to the empty
  # string upstream, which means "delete nothing", so the generation pruning is
  # done entirely by nix-gc-tiered below. The 90d here is a backstop for every
  # other profile on the machine that the tiered job does not know about.
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 90d";
  };

  # ── Tiered profile generation cleanup ─────────────────────────────────────
  # 2026-11-09: the disk filled to 100% and both the weekly flake update and a
  # manual rebuild failed with "No space left on device" while linking
  # nvidia.ko. The old version kept one generation per month for six months and
  # swallowed every error with `2>/dev/null || true`, so nothing was ever logged.
  # This version keeps less, caps the count, prunes the home-manager profile as
  # well, and enforces a free-space floor afterwards.
  systemd.services.nix-gc-tiered = {
    description = "Tiered Nix profile generation cleanup with a free-space floor";
    after = [ "nix-gc.service" ];
    wants = [ "nix-gc.service" ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
      # A failed cleanup must be visible: no `|| true`, no silent redirects.
      StandardError = "journal";
    };
    path = with pkgs; [
      coreutils
      gnused
      gawk
      nix
    ];
    script = ''
      set -euo pipefail

      KEEP_ALL=${toString keepAllDays}
      KEEP_WEEKS=${toString keepWeekly}
      KEEP_MONTHS=${toString keepMonthly}
      MAX_GENS=${toString maxGenerations}
      MIN_FREE=$(( ${toString minFreeGiB} * 1024 * 1024 * 1024 ))
      NOW="$(date +%s)"

      profiles=(
        /nix/var/nix/profiles/system
      )
      # NixOS-integrated home-manager keeps no generation profile of its own, so
      # on this machine only the system profile exists. These globs cover a
      # standalone home-manager or nix-env setup without assuming a user name:
      # this unit runs as root, so `id -un` would always say "root".
      for p in /nix/var/nix/profiles/per-user/*/home-manager \
               /home/*/.local/state/nix/profiles/home-manager; do
        [ -e "$p" ] && profiles+=("$p")
      done

      list_gens() { nix-env --list-generations -p "$1" | awk '$1 ~ /^[0-9]+$/ {print $1, $2, $3}'; }
      current_gen() { nix-env --list-generations -p "$1" | awk '$1 ~ /^[0-9]+$/ && /current/ {print $1; exit}'; }

      # Decide which generations of one profile to remove. Newest first, so the
      # first generation seen inside a week or month bucket is the one kept.
      prune_profile() {
        local prof="$1"
        local -A keep=()
        local -A week_used=()
        local -A month_used=()
        local gen date age bucket cur kept

        if [ ! -e "$prof" ]; then
          echo "skip: $prof does not exist"
          return 0
        fi

        cur="$(current_gen "$prof")"
        [ -n "$cur" ] && keep["$cur"]=1

        while read -r gen date _; do
          [ -n "$gen" ] || continue
          age=$(( (NOW - $(date -d "$date" +%s)) / 86400 ))

          if [ "$age" -le "$KEEP_ALL" ]; then
            keep["$gen"]=1
            continue
          fi

          if [ "$age" -le 31 ]; then
            bucket=$(( (age - KEEP_ALL - 1) / 7 + 1 ))
            if [ "$bucket" -le "$KEEP_WEEKS" ] && [ -z "''${week_used[$bucket]:-}" ]; then
              week_used["$bucket"]=1
              keep["$gen"]=1
            fi
            continue
          fi

          bucket=$(( (age - 31 - 1) / 30 + 1 ))
          if [ "$bucket" -le "$KEEP_MONTHS" ] && [ -z "''${month_used[$bucket]:-}" ]; then
            month_used["$bucket"]=1
            keep["$gen"]=1
          fi
        done < <(list_gens "$prof" | sort -k2,2 -r)

        # Hard cap: keep the current generation plus the newest of the rest.
        kept="$(printf '%s\n' "''${!keep[@]}" | grep -c . || true)"
        if [ "$kept" -gt "$MAX_GENS" ]; then
          for gen in $(printf '%s\n' "''${!keep[@]}" | sort -rn | tail -n "+$((MAX_GENS + 1))"); do
            [ "$gen" = "$cur" ] && continue
            unset "keep[$gen]"
            echo "cap: dropping generation $gen despite its age"
          done
        fi

        while read -r gen date _; do
          [ -n "$gen" ] || continue
          if [ -z "''${keep[$gen]:-}" ]; then
            echo "delete: $prof generation $gen ($date)"
            nix-env --delete-generations -p "$prof" "$gen"
          fi
        done < <(list_gens "$prof")
      }

      free_bytes() { df --output=avail -B1 / | tail -1 | tr -d ' '; }

      # Last resort: the floor. A weekly run cannot prevent a mid-week fill, so
      # this is checked every run and drops the oldest non-current generation
      # until the floor is met.
      enforce_floor() {
        local prof=/nix/var/nix/profiles/system gen cur i=0
        cur="$(current_gen "$prof")"
        while [ "$(free_bytes)" -lt "$MIN_FREE" ] && [ "$i" -lt 20 ]; do
          gen="$(list_gens "$prof" | awk -v cur="$cur" '$1 != cur {print $1}' | head -1)"
          if [ -z "$gen" ]; then
            echo "floor: no deletable generation left, still below ${toString minFreeGiB} GiB free"
            return 0
          fi
          echo "floor: free space low, dropping oldest generation $gen"
          nix-env --delete-generations -p "$prof" "$gen"
          nix-collect-garbage
          i=$((i + 1))
        done
      }

      for prof in "''${profiles[@]}"; do
        prune_profile "$prof"
      done

      nix-collect-garbage
      enforce_floor

      echo "done: $(free_bytes) bytes free, floor is $MIN_FREE"
    '';
  };

  # Daily, not weekly: the free-space floor only protects the machine if it runs
  # more often than the thing that fills the disk.
  systemd.timers.nix-gc-tiered = {
    description = "Daily tiered Nix generation cleanup timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
