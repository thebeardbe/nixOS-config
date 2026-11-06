{ ... }:

{
  # JBL Quantum USB headsets (360X, 360, 350) open their ALSA node with a 1 ms
  # period (48 frames at 48 kHz) on a 32768 frame buffer. PipeWire cannot feed a
  # period that small from a 1024 frame graph, so the stream underruns instantly
  # and `snd_pcm_recover` never restarts it: ALSA stays in XRUN, PipeWire logs
  # `snd_pcm_avail after recover: Broken pipe` every 2 s, the device is silent and
  # any application playing to it stalls (a "buffering" YouTube video is the
  # visible symptom).
  #
  # Overriding one or both properties below yields period_size 512.
  #
  # Investigation, evidence and the 350 pending check:
  # Documents/agent-notes/audio/jbl-quantum-xrun.md
  xdg.configFile."wireplumber/wireplumber.conf.d/99-jbl-period.conf".text = ''
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
    ]
  '';
}
