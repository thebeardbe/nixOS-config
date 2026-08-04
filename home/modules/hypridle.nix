{ ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Command to run when receiving a dbus lock event (from loginctl lock-session)
        lock_cmd = "pidof hyprlock || hyprlock";
        # Lock before suspend
        before_sleep_cmd = "loginctl lock-session";
        # Wake display after resume
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
      };

      listener = [
        {
          timeout = 300; # 5 minutes → lock screen via logind (triggers lock_cmd)
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 330; # 5.5 minutes → turn off display (on-resume wakes it)
          # ignore_inhibit: apps (Steam) hold idle inhibitors which would make
          # hypridle SKIP on-resume → display never wakes. This listener must
          # always respond to real input.
          ignore_inhibit = true;
          # dpms-off script skips if media is playing (MPRIS via playerctl)
          on-timeout = "dpms-off";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
        }
      ];
    };
  };
}
