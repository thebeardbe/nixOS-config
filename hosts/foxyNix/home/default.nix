{ pkgs, ... }: {
  imports = [
    ./waybar.nix
    # Host-specific home modules go here
  ];

  home.packages = with pkgs; [
    # Laptop-specific packages go here
  ];
}
