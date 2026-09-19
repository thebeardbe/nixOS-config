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
        # Wake display after resume. dpms-on also runs hyprctl reload when the
        # outputs are stuck at 0x0, but a reload does NOT restore those modes
        # (measured), so treat 0x0 after a resume as needing a session restart.
        after_sleep_cmd = "dpms-on";
      };

      # No dpms-off listener on purpose. Measured on this machine: a SHORT
      # hl.dsp.dpms() off/on cycle is harmless, but a LONG off (around 10 minutes,
      # long enough for the monitors to actually power down) leaves both outputs
      # at 0x0 on wake ("failed to commit: Invalid argument"). hyprlock then only
      # receives zero-size configures, so it holds the lock and draws nothing: the
      # screen looks frozen and cannot be unlocked. hyprctl reload does NOT restore
      # the modes, so there is no safe automatic repair and no automatic blanking.
      # Turn the screens off by hand instead.
      #
      # Separately, a VT switch toggles the libseat/logind seat and the session can
      # come back holding no input devices at all (hyprctl -j devices empty). That
      # is why this config assumes the session stays on tty1.
      listener = [
        {
          timeout = 300; # 5 minutes → lock screen via logind (triggers lock_cmd)
          # ignore_inhibit: Steam and browsers hold idle inhibitors, and hypridle
          # SKIPS an inhibited listener, which would silently mean "never locks".
          # The lock must always fire, so inhibitors are ignored here. The cost is
          # that media longer than 5 minutes gets locked out.
          ignore_inhibit = true;
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
