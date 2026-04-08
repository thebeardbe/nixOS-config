{ config, pkgs, ... }:

{
  # Zorg dat Hyprlock permissie heeft om je wachtwoord te controleren via PAM
  security.pam.services.hyprlock = {};

  # Optioneel: Schakel kwaliteitscontroles voor wachtwoorden in (veiligheid)
  security.pam.services.login.enableGnomeKeyring = true;

  # Voor een 'Radical Generalist' is polkit essentieel voor permissies in GUI apps
  security.polkit.enable = true;
}
