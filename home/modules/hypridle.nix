{ pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Prevent multiple hyprlock instances from stacking up
        lock_cmd = "pidof hyprlock || hyprlock";
        # Lock the session before suspending
        before_sleep_cmd = "loginctl lock-session";
        # Turn the display back on after waking
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          timeout = 300; # 5 minutes of inactivity
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 330; # 5.5 minutes — lock first, then turn off display
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
}
