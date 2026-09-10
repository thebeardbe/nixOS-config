{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    curl
    htop
    pulseaudio  # pactl CLI for PipeWire-Pulse audio profile switching
    pavucontrol  # PulseAudio GUI (switch audio profiles)

    # Recovery: unlock the graphical session from a TTY when hyprlock crashes
    (pkgs.writeShellScriptBin "unlock-session" (builtins.readFile ../../recovery-scripts/unlock-session))
  ];
}
