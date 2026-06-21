{ config, pkgs, ... }:

{
  # Enable Bluetooth hardware support
  hardware.bluetooth.enable = true;

  # Power on the Bluetooth adapter at boot
  hardware.bluetooth.powerOnBoot = true;

  # Blueman — provides the Bluetooth tray icon and management UI
  services.blueman.enable = true; 

  # CLI and GUI tools for debugging and managing Bluetooth
  environment.systemPackages = with pkgs; [
    bluez       # Core Bluetooth protocol stack + CLI tools (bluetoothctl)
    blueman     # GTK Bluetooth manager (tray applet)
    overskride  # Modern GTK4 Bluetooth client (used in Waybar bluetooth module)
  ];
}
