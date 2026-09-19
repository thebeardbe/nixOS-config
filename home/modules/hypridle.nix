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

      # The 330s dpms-off / dpms-on listener is deliberately NOT configured here.
      # A hl.dsp.dpms({action="disable"/"enable"}) cycle on this machine leaves
      # the session with no input devices at all: libseat's logind backend toggles
      # the seat, aquamarine re-registers the devices, and the session still ends
      # up holding none (hyprctl -j devices empty, zero /dev/input fds), so the
      # keyboard and mouse stay dead until the compositor restarts. Switching VT
      # triggers the same seat toggle. Re-add this only once that is fixed, and
      # after testing a single DPMS cycle on a fresh session.
      listener = [
        {
          timeout = 300; # 5 minutes → lock screen via logind (triggers lock_cmd)
          on-timeout = "loginctl lock-session";
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
