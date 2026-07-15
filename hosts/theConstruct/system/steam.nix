{ ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    protontricks.enable = true;
  };

  # Gaming optimizations (used by Heroic, Steam, etc.)
  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  # Sunshine game streaming host (Moonlight client on laptop connects here)
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;  # Required for Wayland/KMS capture
    openFirewall = true;
  };
}
