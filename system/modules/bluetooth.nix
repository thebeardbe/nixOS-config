{ config, pkgs, ... }:

{
  # 1. Activeer de hardware driver
  hardware.bluetooth.enable = true;

  # 2. Forceer de adapter aan bij het opstarten (Activeert de radio)
  hardware.bluetooth.powerOnBoot = true;

  # 3. Zorg dat de kernel de juiste permissies geeft
  services.blueman.enable = true; 

  # 4. Voeg handige tools toe voor debugging en beheer
  environment.systemPackages = with pkgs; [
    bluez
    blueman
    overskride # De moderne GTK4 client die we in Waybar gebruiken
  ];
}
