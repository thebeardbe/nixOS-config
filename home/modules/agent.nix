{ pkgs, ... }:

{
  # Agent-related configuration.
  # Provides nodejs (which includes npm) for the pi-coding-agent and other JS tools.
  #
  # To install the pi agent run:
  #   npm install -g @earendil-works/pi-coding-agent
  
  home.packages = with pkgs; [
    nodejs  # JavaScript runtime — brings npm along with it
  ];

  # Add npm global binaries directory to PATH
  # This is where `npm install -g` puts executables
  home.sessionVariables = {
    PATH = "$HOME/.npm-global/bin:$PATH";
  };
}
