{ ... }:

{
  imports = [
    ./gpu.nix
    ./steam.nix
    # Future: ./monitors.nix, ./audio.nix, ./boot.nix, etc.
  ];

  networking.hostName = "theConstruct";
}
