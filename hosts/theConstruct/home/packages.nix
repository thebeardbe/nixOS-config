{ pkgs, ... }: {
  home.packages = with pkgs; [
    steam-run
    mangohud
    prismlauncher
    heroic
    p7zip
    # Sets the XWayland primary monitor at session start (see hypr-host.lua)
    xrandr

    # Music production (desk-bound: paired with the Akai MPD218)
    ardour                 # DAW (binary is `ardour9`)
    hydrogen               # Drum machine / sequencer

    # Streaming / recording (Wayland capture via xdg-desktop-portal-hyprland)
    (wrapOBS {
      plugins = with obs-studio-plugins; [
        obs-vkcapture                # Game Capture (Vulkan/OpenGL)
        obs-pipewire-audio-capture   # Per-application audio capture
        obs-backgroundremoval        # AI background removal
        distroav                     # NDI support
        obs-source-record            # Source Record filter
        advanced-scene-switcher      # Auto scene switcher module

        # "Move source" filters used by several scenes. OBS 32.2 deprecated
        # obs_properties_add_button, which trips this plugin's own
        # CMAKE_COMPILE_WARNING_AS_ERROR=ON default and fails the build.
        # Turning that flag off is the minimal fix.
        (obs-move-transition.overrideAttrs (old: {
          cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DCMAKE_COMPILE_WARNING_AS_ERROR=OFF" ];
        }))
      ];
    })
  ];
}
