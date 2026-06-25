{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # Disable deprecated language providers
    withPython3 = false;
    withRuby = false;
    withNodeJs = false;
    
    extraPackages = with pkgs; [
      lua-language-server
      nil                  # Nix language server
      xclip                # Clipboard integration
    ];
  };
}
