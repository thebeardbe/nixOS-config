{ pkgs, ... }: {
  # Enable CUPS for printing
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      # Add specific drivers here if needed, e.g., hplip, brlaser
    ];
  };

  # Enable SANE for scanning
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  # Network discovery for printers/scanners (Avahi is already partially in configuration.nix)
  # Enhancing it here for better discovery support.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      userServices = true;
    };
  };

  # Useful tools for managing hardware
  environment.systemPackages = with pkgs; [
    system-config-printer # Printer management GUI
    simple-scan           # Scanner GUI
  ];
}
