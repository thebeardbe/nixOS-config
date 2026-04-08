{ pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock"; # Voorkom meerdere instances
        before_sleep_cmd = "loginctl lock-session"; # Lock voor suspend
        after_sleep_cmd = "hyprctl dispatch dpms on"; # Scherm aan na wake
      };

      listener = [
        {
          timeout = 300; # 5 minuten
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 330; # 5.5 minuten
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
