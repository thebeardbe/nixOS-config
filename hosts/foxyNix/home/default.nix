{ pkgs, lib, ... }:
{
  imports = [
    ./packages.nix
  ];

  # The sellars entries in the shared home/home.nix deliberately carry no
  # identityFile: a key path is local to one machine. This host reaches sellars
  # with its own key (authorized on the server as thebeardbe@foxyNix->sellars),
  # but its file name here was never recorded, so nothing is declared rather than
  # guessing a path that may not exist. Until it is set, ssh falls back to the
  # agent and the default ~/.ssh/id_* names, then to a password prompt. See
  # NOTES.md, "Declare the sellars key path on foxyNix".

  # Host-specific Hyprland Lua config (touchpad settings)
  home.file.".config/hypr/host.lua".source = ./hypr-host.lua;

  # Idle blanking for this host only. The shared module has no dpms-off listener
  # because a long DPMS off left theConstruct's two outputs at 0x0 with no
  # reliable repair (see home/modules/hypridle.nix). This host has a single Intel
  # eDP panel, and a 15 minute DPMS off followed by a lid-close suspend/resume
  # came back at 1920x1080@59.997, so blank it here.
  #
  # Lock at 5 min, blank at 5.5 min. `dpms-off` exits without touching the
  # display while media is playing, and `dpms-on` on resume is the wake path;
  # `after_sleep_cmd = resume-guard` covers the suspend case.
  services.hypridle.settings.listener = lib.mkForce [
    {
      timeout = 300;
      on-timeout = "loginctl lock-session";
    }
    {
      timeout = 330;
      on-timeout = "dpms-off";
      on-resume = "dpms-on";
    }
  ];
}
