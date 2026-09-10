{ config, pkgs, ... }:

{
  # Real-time audio priority — essential for gaming / low-latency audio
  security.rtkit.enable = true;

  # PipeWire for audio (replaces PulseAudio)
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;  # Required for 32-bit Proton/Wine games
    pulse.enable = true;
  };
}
