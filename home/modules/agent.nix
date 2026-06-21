{ config, pkgs, ... }:

let
  authJson = config.mySecrets.piAuth;
in
{
  home.packages = with pkgs; [
    nodejs
  ];

  home.sessionVariables = {
    PATH = "$HOME/.npm-global/bin:$PATH";
  };

  home.file = {
    ".pi/agent/settings.json".source = ../files/agent/settings.json;
  } // (if authJson != null then {
    ".pi/agent/auth.json".text = authJson;
  } else {});
}
