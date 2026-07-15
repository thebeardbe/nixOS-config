{ pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Lock the screen before suspending
        before_sleep_cmd = "lock-screen";
        # Wake display after resume (proper Lua dispatch syntax)
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
      };

      listener = [
        {
          timeout = 300; # 5 minutes of inactivity → lock + 5s later DPMS off
          on-timeout = "lock-screen";
        }
        {
          timeout = 330; # 30s after lock — safety DPMS off (lock-screen already does this at 5s)
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
        }
      ];
    };
  };
}
