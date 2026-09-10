{ config, pkgs, ... }:

{
  hardware = {
    # OpenGL
    graphics.enable = true;

    # Most Wayland compositors need this
    # nvidia.modesetting.enable = true;
  };
}
