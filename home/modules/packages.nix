{ pkgs, theme, ... }:

{
  home.packages = with pkgs; [
    # Communicatie & Productiviteit
    obsidian
    discord
    signal-desktop
    firefox
    enpass
    gemini-cli
    antigravity
#    neovim
#    commet

    # Fonts & UI
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.meslo-lg    
    networkmanagerapplet
    pavucontrol
    pamixer
    fastfetch
    nwg-look
    tree
    btop
    eza
    bat
    hyprshot


    # sftp in yazi
    glib  # Provides 'gio'
    sshfs # Backend for mounting
    
    # Hier kun je straks gemakkelijk OrcaSlicer en Krita toevoegen
    # orcaslicer
    # krita
  ];
}
