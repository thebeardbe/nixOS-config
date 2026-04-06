{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true; # Zet $EDITOR naar nvim
    viAlias = true;
    vimAlias = true;
    
    # Extra pakketten die Neovim nodig heeft (LSPs, etc.)
    extraPackages = with pkgs; [
      lua-language-server
      nil # Nix language server
      xclip # Voor clipboard ondersteuning
    ];
  };
}
