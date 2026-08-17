{ pkgs, ... }: {
  home.packages = with pkgs; [
    # Game streaming client (connects to Sunshine on theConstruct)
    # moonlight-qt 6.1.0 doesn't compile against FFmpeg 8/9 (AVCodec.pix_fmts removed).
    # Build against FFmpeg 6 instead — the last API-compatible version.
    (moonlight-qt.override { ffmpeg = pkgs.ffmpeg_6; })
  ];
}
