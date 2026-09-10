{ config, pkgs, ... }:

{
  # Enable stock power management tools
  powerManagement.enable = true;

  # Trim SSD for performance
  services.fstrim.enable = true;
}
