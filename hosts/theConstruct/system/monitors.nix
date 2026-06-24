{ lib, pkgs, ... }:

{
  # Monitor configuration
  # Run `hyprctl monitors` to get display names and resolutions
  # Format: monitor = name, resolution@refresh, position, scale
  #
  # Example:
  #   monitor = DP-1, 2560x1440@165, 0x0, 1        # Main (165hz)
  #   monitor = DP-2, 3840x1080, 0, -1440, 1       # Widescreen above
}
