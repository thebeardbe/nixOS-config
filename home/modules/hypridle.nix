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
        # After a resume, wake the display and restart hyprlock if it died while
        # holding the lock (nvidia Xid 13 / SIGABRT on resume). See resume-guard.
        after_sleep_cmd = "resume-guard";
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
          # No ignore_inhibit on purpose: hypridle skips an inhibited listener,
          # and that is the wanted behaviour. A game or a video holds an idle
          # inhibitor, so the idle lock stays out of the way. Super+L and the
          # lock-before-suspend path still lock the session on demand.
          on-timeout = "loginctl lock-session";
        }
        # No idle-suspend listener on purpose. Suspend itself works now (the nvidia
        # powerManagement services stopped the `NVRM: Xid 13` corruption and the
        # screens come back), but every resume so far has lost the input devices:
        # the same libseat/logind seat-toggle bug that a VT switch triggers. Auto
        # suspend would therefore leave the machine unusable while unattended.
        # Suspend manually with `systemctl suspend` until that is fixed.
      ];
    };
  };

  # lock_cmd spawns hyprlock inside hypridle's own cgroup, so the default
  # KillMode=control-group made "systemctl --user stop/restart hypridle" kill
  # the lock screen and silently unlock the session. KillMode=process leaves
  # hyprlock alone when the idle daemon is stopped or restarted.
  systemd.user.services.hypridle.Service.KillMode = "process";
}
