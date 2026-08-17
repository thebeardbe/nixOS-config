{ pkgs, unstable, ... }: {
  home.packages = with pkgs; [
    # Game streaming client (connects to Sunshine on theConstruct)
    # NOTE: main nixpkgs (ffmpeg 9.0) broke moonlight-qt 6.1.0 (AVCodec.pix_fmts removed).
    # nixpkgs-unstable still has ffmpeg 8.1.2 which compiles it fine (prebuilt in cache).
    unstable.moonlight-qt
  ];
}
