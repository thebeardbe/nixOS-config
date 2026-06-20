{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true; # Sets $EDITOR to nvim
    viAlias = true;
    vimAlias = true;
    
    # Extra packages Neovim needs (LSP servers, clipboard)
    extraPackages = with pkgs; [
      lua-language-server  # Lua LSP
      nil                  # Nix language server
      xclip                # Clipboard integration (system clipboard)
    ];
  };
}
