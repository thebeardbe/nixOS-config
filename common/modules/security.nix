{ config, pkgs, ... }:

{
  # PAM service for hyprlock — allows the lockscreen to validate your password
  security.pam.services.hyprlock = {};

  # Enable Gnome Keyring integration with login PAM
  # Stores secrets (SSH keys, GPG, application passwords) unlocked on login
  security.pam.services.login.enableGnomeKeyring = true;

  # PolicyKit — grants permission elevation for GUI apps (mounting drives, etc.)
  # Required for many desktop operations to work without terminal sudo
  security.polkit.enable = true;
}
