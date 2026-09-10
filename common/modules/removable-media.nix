{ config, pkgs, ... }:

{
  # UDisks2 — daemon for mounting removable media (USB sticks, SD cards, external drives)
  # udiskie (home-manager) talks to this over D-Bus to auto-mount on insertion
  services.udisks2.enable = true;

  # enable gVFS for mounting sftp in yazi under /run/user/1000/gvfs
  services.gvfs.enable = true;
}
