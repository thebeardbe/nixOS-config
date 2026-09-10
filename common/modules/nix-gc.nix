{ config, pkgs, ... }:

{
  # ── Nix Garbage Collection ──────────────────────────────────────────────────
  # Automatic GC for the nix store
  # Standard GC: removes only unreachable store paths, NOT profile generations.
  # The tiered cleanup below handles which generations to keep/delete.
  nix.gc = {
    automatic = true;
    dates = "daily";
  };

  # ── Tiered Profile Generation Cleanup ───────────────────────────────────────
  # Keeps: all from last 7d, 1/week for last month, 1/month for last 6 months
  systemd.services.nix-gc-tiered = {
    description = "Tiered NixOS Profile Generation Cleanup";
    after = [ "nix-gc.service" ];
    wants = [ "nix-gc.service" ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
    path = [ pkgs.coreutils pkgs.gnused pkgs.gawk pkgs.nix ];
    environment.NIX_REMOTE = "daemon";
    script = ''
      set -euo pipefail

      PROFILE="/nix/var/nix/profiles/system"
      NOW="$(date +%s)"

      # Get list of generations with their dates (format: generation|date)
      nix-env --list-generations -p "$PROFILE" 2>/dev/null | \
        awk '
          /^[[:space:]]*[0-9]+/ {
            gen = $1
            # Extract date: find the first occurrence of a date pattern
            for (i = 2; i <= NF; i++) {
              if ($i ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
                date = $i
                print gen "|" date
                break
              }
            }
          }
        ' | sort -t'|' -k2,2 > /tmp/nix-generations.txt

      # Build list of generations to keep
      declare -A KEEP_GENS

      while IFS='|' read -r gen date_str; do
        gen_epoch="$(date -d "$date_str" +%s 2>/dev/null || echo "")"
        [ -z "$gen_epoch" ] && continue
        age_days=$(( (NOW - gen_epoch) / 86400 ))

        if [ "$age_days" -le 7 ]; then
          # Keep all generations from the last 7 days
          KEEP_GENS["$gen"]=1
        elif [ "$age_days" -le 30 ]; then
          # Weeks 2-4: keep 1 per week (Sunday of each week)
          week_num=$(( (age_days - 1) / 7 + 1 ))
          # Keep only the newest generation of each week
          if [ -z "''${WEEKLY_KEPT[$week_num]:-}" ]; then
            WEEKLY_KEPT[$week_num]="$gen"
            KEEP_GENS["$gen"]=1
          fi
        elif [ "$age_days" -le 180 ]; then
          # Months 2-6: keep 1 per month (by month number from current)
          month_num=$(( (age_days - 1) / 30 + 1 ))
          if [ -z "''${MONTHLY_KEPT[$month_num]:-}" ]; then
            MONTHLY_KEPT[$month_num]="$gen"
            KEEP_GENS["$gen"]=1
          fi
        fi
      done < /tmp/nix-generations.txt

      # Delete all generations not in KEEP_GENS
      while IFS='|' read -r gen date_str; do
        if [ -z "''${KEEP_GENS[$gen]:-}" ]; then
          echo "Deleting generation $gen ($date_str)"
          nix-env --delete-generations -p "$PROFILE" "$gen" 2>/dev/null || true
        fi
      done < /tmp/nix-generations.txt

      # Run standard GC to free store space from deleted generations
      nix-collect-garbage 2>/dev/null || true
    '';
  };

  # Run tiered cleanup weekly on Sundays
  systemd.timers.nix-gc-tiered = {
    description = "Weekly Tiered NixOS Generation Cleanup Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
