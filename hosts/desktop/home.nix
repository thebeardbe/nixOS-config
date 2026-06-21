# The Construct-specific home config
{ pkgs, ... }: {
  home.packages = with pkgs; [
    # Gaming
    steam-run           # Run non-Steam games/software
    mangohud            # Performance overlay (FPS, temps, etc.)
    prismlauncher       # Minecraft launcher
  ];
}
