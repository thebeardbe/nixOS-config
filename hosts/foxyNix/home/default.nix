{ pkgs, ... }: {
  imports = [
    # Host-specific home modules go here
  ];

  home.packages = with pkgs; [
    # Laptop-specific packages go here
  ];
}
