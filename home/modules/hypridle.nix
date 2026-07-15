{ pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Lock the screen before suspending
        before_sleep_cmd = "lock-screen";
        # Wake display after resume
        after_sleep_cmd = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
      };

      listener = [
        {
          timeout = 300; # 5 minutes → lock screen
          on-timeout = "lock-screen";
        }
        {
          timeout = 330; # 5.5 minutes → turn off display (on-resume wakes it on activity)
          on-timeout = "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'";
          on-resume = "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'";
        }
      ];
    };
  };
}
