{ ... }:

{
  # JBL Quantum USB headsets (360X, 360, 350) open their ALSA node with a 1 ms
  # period (48 frames at 48 kHz) on a 32768 frame buffer. PipeWire cannot feed a
  # period that small from a 1024 frame graph, so the stream underruns instantly
  # and `snd_pcm_recover` never restarts it: ALSA stays in XRUN, PipeWire logs
  # `snd_pcm_avail after recover: Broken pipe` every 2 s, the device is silent and
  # any application playing to it stalls (a "buffering" YouTube video is the
  # visible symptom). Overriding the period and headroom yields period_size 512.
  #
  # The 360X also exposes two playback PCMs: pro-output-0 is 2ch/48000 (game) and
  # pro-output-1 is 1ch/16000 (chat). Only the pro-audio profile exposes them as
  # separate nodes, which is what makes per-program routing possible (game on
  # pro-output-0, Discord on pro-output-1). The profile is selected automatically,
  # and pro-output-0 is given the highest session priority so ordinary audio does
  # not land on the mono 16 kHz chat channel.
  #
  # Caveat: WirePlumber remembers the last profile per card in
  # ~/.local/state/wireplumber/default-profile, and a remembered choice beats
  # these rules. Manually picking another profile for a JBL card therefore wins
  # until that line is deleted. The same applies to the default sink in
  # default-nodes.
  #
  # Investigation and verification recipe:
  # Documents/agent-notes/audio/jbl-quantum-xrun.md
  xdg.configFile."wireplumber/wireplumber.conf.d/99-jbl-headsets.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [
          { node.name = "~alsa_output.usb-JBL.*" }
          { node.name = "~alsa_input.usb-JBL.*" }
        ]
        actions = {
          update-props = {
            api.alsa.period-size = 1024
            api.alsa.headroom    = 8192
          }
        }
      }
      {
        matches = [ { device.name = "alsa_card.usb-JBL_JBL_Quantum_360X_Wireless-00" } ]
        actions = { update-props = { device.profile = "pro-audio" } }
      }
      {
        matches = [ { node.name = "~alsa_output.usb-JBL.*pro-output-0" } ]
        actions = { update-props = { priority.session = 2500 } }
      }
    ]
  '';
}
