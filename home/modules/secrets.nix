{ lib, ... }:

# Declares secret options available to home-manager modules.
# Values are provided by the private nix-secrets flake input.

{
  options.mySecrets = {
    piAuth = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "pi-coding-agent auth.json content (JSON string)";
    };
  };
}
