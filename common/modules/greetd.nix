{ config, pkgs, ... }:

{
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --user-menu --asterisks --theme 'border=blue;text=blue;prompt=blue;time=blue;action=blue;button=blue;container=black;input=blue' --cmd 'Hyprland -c /home/thebeardbe/.config/hypr/hyprland.lua'";
        user = "greeter";
      };
    };
  };

  # Optional: ensure tuigreet looks good on TTY
  systemd.services.greetd.serviceConfig = {
    Type = "idle";
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal"; # Better for debugging
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };
}
