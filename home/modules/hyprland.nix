{ config, pkgs, lib, theme, ... }:

with lib;

let
  formatColor = color:
    let
      raw = removePrefix "#" color;
    in
      toUpper raw;
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      # --- Variabelen ---
      "$mod" = "SUPER";
      "$terminal" = "kitty";
      "$menu" = "wofi --show drun";
      "$fileManager" = "kitty -e yazi"; # Start Yazi direct in een terminal
      # --- Monitor Config ---
      # "preferred, auto, 1" kiest de beste resolutie en zet hem op de juiste plek.
      monitor = ", preferred, auto, 1";
      exec-once = [ 
	"nm-applet --indicator" # Wifi icon
	"${pkgs.quickshell}/bin/quickshell -f /home/thebeardbe/.config/quickshell/shell.qml" # Our custom bar and wallpaper
      ];
      
      # --- Look & Feel ---
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = "0xff${formatColor theme.colors.accent}";
        "col.inactive_border" = "0xaa${formatColor theme.colors.background}";
        layout = "dwindle";
        allow_tearing = false;
      };

      decoration = {
        rounding = 10;
	#Transparancy
	active_opacity = 0.95;
	inactive_opacity = 0.75;
	fullscreen_opacity = 1.0;
        blur = {
          enabled = true;
          size = 3;
          passes = 1;
	  xray = true; # Better rendering only renders what is needed
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };
      };
      
      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
#          "bordercycle, 1, 10, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      # --- Window Management Binds ---
      bind = [
        # Basis acties
        "$mod, Q, exec, $terminal"
        "$mod, C, killactive,"
        "$mod, M, exit,"
        "$mod, E, exec, $fileManager"
        "$mod, V, togglefloating,"
        "$mod, space, exec, $menu"
        "$mod, P, pseudo," # dwindle
        "$mod, J, togglesplit," # dwindle
        "$mod, F, fullscreen,"

        # Focus verplaatsen (Vim-stijl of pijltjes)
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Switchen tussen workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
	"$mod, 6, workspace, 6"
	"$mod, 7, workspace, 7"
	"$mod, 8, workspace, 8"
	"$mod, 9, workspace, 9"
	"$mod, 0, workspace, 0"

        # Window verplaatsen naar workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
	"$mod SHIFT, 6, movetoworkspace, 6"
	"$mod SHIFT, 7, movetoworkspace, 7"
	"$mod SHIFT, 8, movetoworkspace, 8"
	"$mod SHIFT, 9, movetoworkspace, 9"
	"$mod SHIFT, 0, movetoworkspace, 0"

        # Screenshots (met hyprshot)
        ", Print, exec, hyprshot -m output"
        "$mod, Print, exec, hyprshot -m window"

	# Volume regeling
        ", XF86AudioRaiseVolume, exec, pamixer -i 5"
        ", XF86AudioLowerVolume, exec, pamixer -d 5"
        ", XF86AudioMute, exec, pamixer -t"
	
	# Systeem locken (Super + L)
        "$mod, L, exec, hyprlock"

        # Hyprland reloaden (Super + Shift + R)
        # Dit herlaadt de config zonder programma's te sluiten
        "$mod SHIFT, R, exec, hyprctl reload"
      ];

      # Muis acties (vasthouden om te verplaatsen/resizen)
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };

  # De ondersteunende tools voor de Hypr-ervaring
  home.packages = with pkgs; [
    yazi         # De ster van de show
    ffmpegthumbnailer # Voor video previews in Yazi
    jq           # Voor JSON previews
    poppler      # Voor PDF previews
    fd           # Snellere search voor Yazi
    ripgrep      # Snellere content search
    fzf          # Fuzzy finder integratie

    hyprlock     # Lockscreen
    hypridle     # Auto-sleep
    hyprshot     # Screenshot tool
    wofi         # De applicatie launcher
    kitty        # Je terminal
    libnotify    # Voor notificaties
    swaynotificationcenter # Notificatie paneel
  ];
}
