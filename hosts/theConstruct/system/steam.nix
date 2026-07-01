{ ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Gaming optimizations (used by Heroic, Steam, etc.)
  programs.gamescope.enable = true;
  programs.gamemode.enable = true;
}
