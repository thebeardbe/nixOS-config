{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./system/default.nix
    ../../common/configuration.nix
  ];

  # Single updater host: theConstruct owns the shared flake.lock update.
  mySystem.flakeUpdate.enable = true;
}
