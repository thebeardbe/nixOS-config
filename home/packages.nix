{ pkgs, unstable, theme, ... }:

{
  home.packages = with pkgs; [
    # Communication & Productivity
    obsidian         # Note-taking / knowledge base
    discord          # Voice/text chat
    unstable.signal-desktop   # Encrypted messaging (from unstable for latest version)
    firefox          # Web browser
    enpass           # Password manager
    gemini-cli       # Google Gemini CLI

    # Fonts & UI
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.meslo-lg    
    networkmanagerapplet   # NM tray icon (launched in Hyprland's exec-once)
    pavucontrol            # PulseAudio volume mixer
    pamixer                # CLI volume control (used in Hyprland keybinds)
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
    hyprshell              # GTK4 window switcher with thumbnails (Alt+Tab)
    wofi                   # Application launcher
    kitty                  # Terminal emulator
    hyprpaper              # Dynamic wallpaper manager
    wlogout                # Power menu

    # Utilities
    fzf                    # Fuzzy finder (used by pick-wallpaper)
    screen                 # Terminal multiplexer
    libnotify              # Notification daemon (notify-send)
    swaynotificationcenter # Notification center UI

    # Yazi dependencies (previews, search)
    ffmpegthumbnailer      # Video thumbnails
    jq                     # JSON previews
    poppler                # PDF previews
    fd                     # Fast file search
    ripgrep                # Fast content search

    # Playwright / antigravity
    playwright-driver.browsers
    glib                   # GLib (provides 'gio' for SFTP mounting)
    expat                  # XML parser (needed by some Electron apps)
    libxshmfence           # Shared memory fence (needed by Chromium/Electron)
    libGL                  # OpenGL library

    # SFTP mounting in Yazi
    sshfs
  ];
}
