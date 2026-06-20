{ pkgs, theme, ... }:

{
  # User-level packages — apps, tools, and fonts installed per-user
  # System-level packages are in system/configuration.nix and system/modules/
  home.packages = with pkgs; [
    # Communication & Productivity
    obsidian         # Note-taking / knowledge base
    discord          # Voice/text chat
    signal-desktop   # Encrypted messaging
    firefox          # Web browser
    enpass           # Password manager
    gemini-cli       # Google Gemini CLI
    antigravity      # Custom FHS env for Playwright-based app

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
    hyprshot               # Screenshot tool
    brightnessctl          # Brightness control (used in Hyprland keybinds)
    playwright-driver.browsers # Browser engines for Playwright
    glib                   # GLib utility library (provides 'gio' for SFTP mounting)
    expat                  # XML parser (needed by some Electron apps)
    libxshmfence           # Shared memory fence (needed by Chromium/Electron)
    libGL                  # OpenGL library

    # SFTP mounting in Yazi — allows browsing remote servers
    sshfs # FUSE-based SSH filesystem
  ];
}
