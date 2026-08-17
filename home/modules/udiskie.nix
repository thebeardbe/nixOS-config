{ ... }: {

  # udiskie — auto-mounts removable media (USB sticks, SD cards, external drives)
  # as soon as they're plugged in. Runs as a user service in the graphical session.
  services.udiskie = {
    enable = true;
    automount = true;   # Mount on insertion (default)
    notify = true;      # Pop-up notification on mount/unmount
    tray = "auto";      # Tray icon only when a device is present (Waybar tray)
  };
}
