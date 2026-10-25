# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include all systemwide modules.
     ./modules/bluetooth.nix
     ./modules/touchpad.nix
     ./modules/users.nix
     ./modules/security.nix
     ./modules/hardware.nix
     ./modules/audio.nix
     ./modules/networking.nix
     ./modules/locale.nix
     ./modules/nix.nix
     ./modules/nix-gc.nix
     ./modules/flake-update.nix
     ./modules/portals.nix
     ./modules/greetd.nix
     ./modules/power.nix
     ./modules/removable-media.nix
     ./modules/desktop.nix
     ./modules/virtualisation.nix
     ./modules/graphics.nix
     ./modules/system-packages.nix
    ];

  # Swap file. Cold pages only: zram (below) is the fast tier.
  swapDevices = [ { device = "/swapfile"; size = 8192; } ];

  # --- Behaviour under memory pressure ---
  # foxyNix has 7.5 GiB and regularly runs Firefox (28 content processes, ~4 GiB),
  # Steam and Electron apps at once. Before this the kernel thrashed the
  # swapfile: memory PSI ~86%, IO PSI ~98%, load ~17 on 4 threads, six OOM kills
  # in one boot. Both settings below target that specific failure shape.
  #
  # Compressed swap in RAM. The module's default priority of 5 already puts it
  # ahead of the swapfile at -1, so eviction costs a zstd round trip instead of
  # an NVMe round trip.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50; # of RAM, allocated on demand, not reserved up front
  };

  # Prefer zram over the swapfile. Only safe at this value because zram is
  # memory-speed; with a disk-only swap it would make thrashing worse.
  boot.kernel.sysctl."vm.swappiness" = 150;

  # Kill the memory hog on PSI pressure instead of freezing the desktop for
  # minutes and then shooting an arbitrary process. Root slice covers system
  # services, user slices cover the browser, Steam and the agents.
  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableUserSlices = true;
  };

  system.stateVersion = "25.11";
}
