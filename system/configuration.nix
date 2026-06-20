# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-gen.nix
      # Include all systemwide modules.
     ./modules/bluetooth.nix 
     ./modules/touchpad.nix
     ./modules/users.nix
     ./modules/security.nix
     ./modules/hardware.nix
    ];

  # Enable touchpad settings (custom module defined in ./modules/touchpad.nix)
  # Toggle this to false to use default libinput settings
  mySystem.touchpad.enable = true;

  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    consoleMode = "max";
  };
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Enable Plymouth for an Otherland-style boot splash
  boot.plymouth = {
    enable = true;
    # Add a futuristic theme if available
  };
  # Silent boot for a more VR-like feel
  boot.kernelParams = [ "quiet" "splash" "boot.shell_on_fail" "loglevel=3" "rd.systemd.show_status=false" "rd.udev.log_level=3" "udev.log_priority=3" ];
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  # Dual-boot with Ubuntu: detect and add Ubuntu entry to systemd-boot
  boot.loader.grub.useOSProber = true;
  boot.loader.systemd-boot.extraEntries = {
    "ubuntu.conf" = ''
      title Ubuntu
      efi /EFI/ubuntu/shimx64.efi
    '';
  };
  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "foxyNix"; # Define your hostname.
  #  networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable tailscale
  services.tailscale.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Brussels";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Configure keymap in X11 and wayland
  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
  };
  
  # Enable stock power management tools
  powerManagement.enable = true;
  
  # Prevent overheating on Intel CPU
  services.thermald.enable = true;

  # Trim SSD for performance
  services.fstrim.enable = true;

  # Swap file
  swapDevices = [ { device = "/swapfile"; size = 8192; } ];

  # Flatpak
  services.flatpak.enable = true;

  # Let Hyprland handle the power key instead of systemd
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # Docker
  virtualisation.docker.enable = true;
  users.users.thebeardbe.extraGroups = [ "docker" ];

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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    curl
    htop
  ];

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  # services.displayManager.sddm.enable = true;
  # services.displayManager.sddm.wayland.enable = true;
  
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
            --time \
            --remember \
            --user-menu \
            --asterisks \
            --theme 'border=blue;text=blue;prompt=blue;time=blue;action=blue;button=blue;container=black;input=blue' \
            --cmd Hyprland
        '';
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
