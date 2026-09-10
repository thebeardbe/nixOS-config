# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, pkgs, ... }:

{
  # Real-time audio priority — essential for gaming / low-latency audio
  security.rtkit.enable = true;

  # PipeWire for audio (replaces PulseAudio)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;  # Required for 32-bit Proton/Wine games
    pulse.enable = true;
  };

  imports =
    [ # Include all systemwide modules.
     ./modules/bluetooth.nix 
     ./modules/touchpad.nix
     ./modules/users.nix
     ./modules/security.nix
     ./modules/hardware.nix
    ];

  # Enable touchpad settings (custom module defined in ./modules/touchpad.nix)
  # Toggle this to true on machines with a touchpad

  # Bootloader — moved per-host systems

  # Use dbus-broker (GNOME default, avoids switch inhibitor warning)
  services.dbus.implementation = "broker";
  services.resolved.enable = true;

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable tailscale
  services.tailscale = {
    enable = true;
    # Don't accept routes from other nodes — avoids interfering with local LAN
    extraUpFlags = [ "--accept-routes=false" ];
  };

  # Set your time zone.
  time.timeZone = "Europe/Brussels";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11 and wayland
  services.xserver.xkb = {
    layout = "us";
    variant = "altgr-intl";
  };

  # Enable stock power management tools
  powerManagement.enable = true;

  # Prevent overheating on Intel CPU
  services.thermald.enable = true;

  # Trim SSD for performance
  services.fstrim.enable = true;

  # UDisks2 — daemon for mounting removable media (USB sticks, SD cards, external drives)
  # udiskie (home-manager) talks to this over D-Bus to auto-mount on insertion
  services.udisks2.enable = true;

  # Kernel support for removable-media filesystems: exFAT (SD cards/USB sticks)
  # and NTFS (Windows drives, via kernel ntfs3 driver)
  boot.supportedFilesystems = [ "exfat" "ntfs3" ];

  # Swap file
  swapDevices = [ { device = "/swapfile"; size = 8192; } ];

  # Flatpak
  services.flatpak.enable = true;

  # Let Hyprland handle the power key instead of systemd
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # Docker
  virtualisation.docker.enable = true;

  # Configure keymap in console
  console.keyMap = "us-acentos";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # use Flakes and experimental
  nix.settings.experimental-features = [ " nix-command" "flakes"];

  # ── Nix Garbage Collection ──────────────────────────────────────────────────
  # Automatic GC for the nix store
  # Standard GC: removes only unreachable store paths, NOT profile generations.
  # The tiered cleanup below handles which generations to keep/delete.
  nix.gc = {
    automatic = true;
    dates = "daily";
  };

  # Auto-optimise store (deduplicate identical files)
  nix.settings.auto-optimise-store = true;

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
      declare -a DAY_GENS  # generations per day for the 7-day keep-all

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

  # Weekly flake update + rebuild (Monday 4am, randomized).
  # Updates the shared flake.lock as thebeardbe (keeps git ownership sane),
  # then rebuilds the CURRENT host (flake attr = hostname). Output lands in
  # journald automatically — no logger pipes needed.
  systemd.services.nix-flake-update = {
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
        ${pkgs.util-linux}/bin/runuser -u thebeardbe -- ${pkgs.coreutils}/bin/env HOME=/home/thebeardbe ${pkgs.git}/bin/git commit -m "chore: weekly flake update" -- flake.lock
      fi
      # rebuild as root with root's HOME (libgit2 repo-ownership check);
      # SUDO_UID makes nix's git fetcher accept thebeardbe-owned repo (same
      # mechanism as a real sudo invocation)
      ${pkgs.coreutils}/bin/env HOME=/root SUDO_UID=1000 ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake /home/thebeardbe/nixOS-config#$(${pkgs.coreutils}/bin/cat /etc/hostname)
    '';
  };
  systemd.timers.nix-flake-update = {
    description = "Weekly Nix flake update timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Mon 04:00";
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    curl
    htop
    pulseaudio  # pactl CLI for PipeWire-Pulse audio profile switching
    pavucontrol  # PulseAudio GUI (switch audio profiles)

    # Recovery: unlock the graphical session from a TTY when hyprlock crashes
    (pkgs.writeShellScriptBin "unlock-session" (builtins.readFile ../recovery-scripts/unlock-session))
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  system.stateVersion = "25.11";

  # services.displayManager.sddm.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --user-menu --asterisks --theme 'border=blue;text=blue;prompt=blue;time=blue;action=blue;button=blue;container=black;input=blue' --cmd 'Hyprland -c /home/thebeardbe/.config/hypr/hyprland.lua'";
        user = "greeter";
      };
    };
  };

  # Optional: ensure tuigreet looks good on TTY
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal"; # Better for debugging
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  # Make Hyprland available system-wide (needed for greetd to launch it)
  # The actual theming/binds are configured in home-manager: home/modules/hyprland.nix
  programs.hyprland = {
    enable = true;
    # nvidiaPatches = true;
    xwayland.enable = true;
  };

  # GNOME portal provides org.freedesktop.portal.Background (needed by Packet's
  # "run in background" mode). Only Background is routed to it — everything else
  # keeps using the gtk/hyprland portals.
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  xdg.portal.config.common = {
    "org.freedesktop.impl.portal.Background" = "gnome";
    "org.freedesktop.impl.portal.Screenshot" = "hyprland";
    "org.freedesktop.impl.portal.ScreenCast" = "hyprland";
    "org.freedesktop.impl.portal.GlobalShortcuts" = "hyprland";
    "org.freedesktop.impl.portal.RemoteDesktop" = "hyprland";
  };
  # The GNOME portal segfaults on resume (libgtk-4). Auto-restart it so
  # Packet's background mode recovers without a manual restart.
  systemd.user.services."xdg-desktop-portal-gnome" = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "2";
    };
  };


  # enviroment settings
  environment.sessionVariables = {
     # If cursor becomes invisible
     WLR_NO_HARDWARE_CURSORS = "1";

     # Hint electron apps to use wayland
     NIXOS_OZONE_WL = "1";
  };

  hardware = {
    #Opengl
    graphics.enable = true;

    # Most Wayland compositors need this
    # nvidia.modesetting.enable = true;
  };

  # enable gVFS for mounting sftp in yazi under /run/user/1000/gvfs
  services.gvfs.enable = true;
}
