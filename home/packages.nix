{ pkgs, unstable, theme, ... }:

{
  home.packages = with pkgs; [
    # Communication & Productivity
    obsidian         # Note-taking / knowledge base
    discord          # Voice/text chat
    unstable.signal-desktop   # Encrypted messaging (from unstable for latest version)
    firefox          # Web browser
    chromium         # Alternative web browser
    enpass           # Password manager

    # Fonts & UI
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.meslo-lg    
    networkmanagerapplet   # NM tray icon (launched in Hyprland's exec-once)
    pavucontrol            # PulseAudio volume mixer
    pamixer                # CLI volume control (used in Hyprland keybinds)
    playerctl              # MPRIS media control (used to detect video playback)
    fastfetch              # System info display
    nwg-look               # GTK settings GUI for Hyprland
    tree                   # Directory tree viewer
    btop                   # Resource monitor (used in Waybar battery onClick)
    eza                    # Modern ls replacement (used in Zsh ls alias)
    bat                    # cat replacement with syntax highlighting
    brightnessctl          # Brightness control (used in Hyprland keybinds)

    # Hyprland ecosystem
    hyprlock               # Lockscreen
    hypridle               # Auto-sleep/idle daemon
    hyprshot               # Screenshot tool
    wl-clipboard           # Wayland clipboard (wl-copy/wl-paste for kitty/terminal copy)
    fuzzel                 # Application launcher (Super + Space)
    packet                 # Quick Share client for Linux (native Android Quick Share protocol)
    kitty                  # Terminal emulator
    hyprpaper              # Dynamic wallpaper manager
    wlogout                # Power menu

    # Media
    mpv                    # Video/audio player (local files + network streams)
    yt-dlp                 # Lets mpv stream from YouTube and similar sites

    # 3D printing
    orca-slicer            # Slicer for Bambu/Prusa/others (2.4.2, matches upstream)

    # File management
    cosmic-files           # GUI file browser (Rust/COSMIC, Wayland-native, mouse-first)

    # Development
    # Bare nixpkgs python3 ships no pip, so the interpreter is wrapped with pip,
    # setuptools and wheel. Packages install into a venv, never into the store.
    (python3.withPackages (ps: [ ps.pip ps.setuptools ps.wheel ]))
    uv                     # Provides uvx, which runs the jcodemunch-mcp MCP server (fetched from PyPI at call time)

    # Utilities
    wtype                  # Virtual keyboard input (Moonlight streaming key injection)
    fzf                    # Fuzzy finder (used by pick-wallpaper)
    screen                 # Terminal multiplexer
    libnotify              # Notification daemon (notify-send)
    swaynotificationcenter # Notification center UI
    unzip                  # Info-ZIP unzip (file managers and scripts call `unzip` by name)

    # Yazi dependencies (previews, search)
    ffmpegthumbnailer      # Video thumbnails
    jq                     # JSON previews
    poppler                # PDF previews
    fd                     # Fast file search
    ripgrep                # Fast content search

    # Shared libraries (Electron apps, yazi SFTP)
    glib                   # GLib (provides 'gio' for SFTP mounting)
    expat                  # XML parser (needed by some Electron apps)
    libxshmfence           # Shared memory fence (needed by Chromium/Electron)
    libGL                  # OpenGL library

    # Report a system update that the weekly check has built but not activated.
    # The weekly timer no longer switches (a kernel/NVIDIA bump breaks the GPU
    # until reboot), so this is how you see what is waiting.
    (writeShellScriptBin "os-update-status" ''
      marker="$HOME/.cache/nixos-update-available"
      if [ -s "$marker" ]; then
        cat "$marker"
        echo ""
        echo "It is already the boot default, so just:  reboot   (when convenient)"
      else
        echo "No staged update."
        echo "The check runs weekly (Monday ~04:00, nix-flake-update.timer)."
        echo "Run it now with:  sudo systemctl start nix-flake-update"
      fi
    '')

    # SFTP mounting in Yazi
    sshfs
  ];
}
