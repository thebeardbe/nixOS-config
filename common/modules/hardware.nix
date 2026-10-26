{ pkgs, ... }: {
  # Enable CUPS for printing
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint
      epson-escpr
    ];
  };

  # Enable SANE for scanning
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];
  };

  # Network discovery for printers/scanners via mDNS (Avahi/Bonjour)
  # Enables automatic discovery on the local network
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    # Renamed upstream: publish.* moved under settings.publish with
    # negated names (NixOS 26.11).
    settings.publish = {
      publish-addresses = true;
      disable-publishing = false;
      disable-user-service-publishing = false;
    };
  };

  # Useful tools for managing hardware
  environment.systemPackages = with pkgs; [
    system-config-printer # Printer management GUI
    simple-scan           # Scanner GUI
  ];
}
