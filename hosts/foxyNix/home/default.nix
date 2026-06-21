{ pkgs, ... }: {
  imports = [
    # Host-specific home modules go here
    # Example: ./touchpad-fix.nix
  ];

  home.packages = with pkgs; [
    # Laptop-specific packages go here
  ];
}
