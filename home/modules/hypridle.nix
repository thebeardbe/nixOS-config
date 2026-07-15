{ pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Lock the session before suspending
        before_sleep_cmd = "lock-screen";
        # Turn the display back on after waking (Lua syntax for DPMS)
        after_sleep_cmd = "hyprctl eval 'hl.dsp.dpms(\"on\")'";
      };

      listener = [
        {
          timeout = 300; # 5 minutes of inactivity → lock + 5s later DPMS off
          on-timeout = "lock-screen";
        }
        {
          timeout = 330; # 30s after lock — safety DPMS off (lock-screen already does this)
          on-timeout = "hyprctl eval 'hl.dsp.dpms(\"off\")'";
          on-resume = "hyprctl eval 'hl.dsp.dpms(\"on\")'";
        }
      ];
    };
  };
}
