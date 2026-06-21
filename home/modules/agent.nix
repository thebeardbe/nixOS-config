{ pkgs, ... }:

{
  # Deploys pi-coding-agent config files.
  # After first build, run: npm install -g @earendil-works/pi-coding-agent
  #
  # NOTE: auth.json contains API keys. Keep the repo private
  #       or move auth.json to a separate secrets repo.

  home.packages = with pkgs; [
    nodejs  # JavaScript runtime — brings npm along with it
  ];

  home.sessionVariables = {
    PATH = "$HOME/.npm-global/bin:$PATH";
  };

  home.file = {
    ".pi/agent/settings.json".source = ./files/agent/settings.json;
    ".pi/agent/auth.json".source = ./files/agent/auth.json;
  };
}
