{ config, pkgs, ... }:

let
  authFile = ../files/agent/auth.json;
  hasAuth = builtins.pathExists authFile;
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
  } // (if hasAuth then {
    ".pi/agent/auth.json".source = ../files/agent/auth.json;
  } else {});
}
