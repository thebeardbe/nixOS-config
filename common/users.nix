{ config, pkgs, ... }:

{
  # Define the main user account — thebeardbe
  # Groups grant specific permissions and access to hardware/services
  users.users.thebeardbe = {
    isNormalUser = true;
    description = "TheBeardBE";
    extraGroups = [ 
      "networkmanager"   # Network management (nm-applet, nmcli)
      "wheel"            # sudo privileges
      "video"            # Hardware access (brightness, webcam)
      "audio"            # Direct audio device access
      "input"            # libinput/touchpad permissions
      "docker"           # Docker daemon access (enabled in configuration.nix)
      "lp"               # Printing (CUPS)
      "scanner"          # Scanning (SANE)
    ];
    # Shell set to zsh (configured via home-manager in starship.nix)
    shell = pkgs.zsh; 
  };

  # Enable zsh system-wide so it's available as a login shell
  programs.zsh.enable = true;
}
