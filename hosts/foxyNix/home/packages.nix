{ pkgs, ... }: {
  home.packages = with pkgs; [
    moonlight-qt  # Game streaming client (connects to Sunshine on theConstruct)
  ];
}
