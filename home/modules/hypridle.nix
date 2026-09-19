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
        # Wake display after resume (dpms-on also repairs stuck outputs)
        after_sleep_cmd = "dpms-on";
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
          # dpms-on wakes the display, then reloads the config if the DPMS cycle
          # left the outputs at 0x0 (otherwise the lock screen stays invisible)
          on-resume = "dpms-on";
        }
      ];
    };
  };

  # lock_cmd spawns hyprlock inside hypridle's own cgroup, so the default
  # KillMode=control-group made "systemctl --user stop/restart hypridle" kill
  # the lock screen and silently unlock the session. KillMode=process leaves
  # hyprlock alone when the idle daemon is stopped or restarted.
  systemd.user.services.hypridle.Service.KillMode = "process";
}
