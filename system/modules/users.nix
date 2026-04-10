{ config, pkgs, ... }:

{
  # Definieer je gebruikersaccount
  users.users.thebeardbe = {
    isNormalUser = true;
    description = "TheBeardBE";
    extraGroups = [ 
      "networkmanager" 
      "wheel"     # Voor sudo permissies
      "video"     # Voor toegang tot hardware (helderheid/webcam)
      "audio"     # Voor directe audio toegang indien nodig
      "input"     # Voor libinput/touchpad permissies
      "docker"    # Als je dit later toevoegt
      "lp"        # Voor printen
      "scanner"   # Voor scannen
    ];
    # Gebruik zsh of fish als je die verkiest boven bash
    shell = pkgs.zsh; 
  };

  # Activeer de shell op systeemniveau
  programs.zsh.enable = true;

  # Handige extra's voor Zsh
  programs.zsh = {
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  # Voeg algemene user-packages toe die op systeemniveau handig zijn
  environment.systemPackages = with pkgs; [
    git
    vim
    wget
    curl
    htop
  ];
}
