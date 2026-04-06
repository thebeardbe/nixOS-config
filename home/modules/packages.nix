{ pkgs, theme, ... }:

{
  home.packages = with pkgs; [
    # Communicatie & Productiviteit
    obsidian
    discord
    signal-desktop
    firefox
    enpass
    antigravity
#    commet

    # Fonts & UI
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.meslo-lg    
    networkmanagerapplet
    pavucontrol
    pamixer
    fastfetch

    # Hier kun je straks gemakkelijk OrcaSlicer en Krita toevoegen
    # orcaslicer
    # krita
  ];
}
