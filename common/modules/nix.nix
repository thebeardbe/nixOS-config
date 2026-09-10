{ config, pkgs, ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # use Flakes and experimental
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Auto-optimise store (deduplicate identical files)
  nix.settings.auto-optimise-store = true;
}
