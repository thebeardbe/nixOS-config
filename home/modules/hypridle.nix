{ pkgs, ... }:

{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        # Lock the screen before suspending
        before_sleep_cmd = "lock-screen";
        # Wake display after resume
        after_sleep_cmd = "hyprctl eval 'hl.dsp.dpms(\"on\")'";
      };

      listener = [
        {
          timeout = 300; # 5 minutes → lock screen (display stays on)
          on-timeout = "lock-screen";
        }
      ];
    };
  };
}
