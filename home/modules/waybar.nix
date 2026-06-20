{ pkgs, theme, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = true; # Let systemd manage the Waybar process
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 4;
        modules-left = [ "hyprland/workspaces" "hyprland/mode" ];
        modules-center = [ "hyprland/window" "clock" ];
        modules-right = [ "backlight" "pulseaudio" "bluetooth" "cpu" "memory" "battery" "tray" "custom/power" ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}  {windows}";
          format-window-separator = " ";
          on-click = "activate";
          window-rewrite-default = "*";
          window-rewrite = {
            "class<firefox>" = "󰈹";         # Firefox
            "class<kitty>" = "";            # Kitty terminal
            "class<Alacritty>" = "";       # Alacritty terminal
            "class<code>" = "󰨞";            # VS Code
            "class<nautilus>" = "󰉋";        # Files
            "class<org.gnome.Nautilus>" = "󰉋";
            "class<thunar>" = "󰉋";          # Thunar file manager
            "class<discord>" = "󰙯";         # Discord
            "class<slack>" = "󰒱";           # Slack
            "class<spotify>" = "󰓇";         # Spotify
            "class<firefox> title<.*youtube.*>" = "";  # YouTube
            "class<zen>" = "󰈹";             # Zen browser
            "class<google-chrome>" = "";   # Chrome
            "class<chromium>" = "";         # Chromium
            "class<obsidian>" = "󰠮";        # Obsidian
            "class<evince>" = "󰈙";          # Document viewer
            "class<hyprlock>" = "󰌾";        # Lock screen
            "class<pavucontrol>" = "󰓃";     # Audio controls
            "class<blueman-manager>" = "󰂯"; # Bluetooth
          };
        };

        "backlight" = {
          format = "{icon} {percent}%";
          format-icons = ["󰃞" "󰃟" "󰃠"];
          on-scroll-up = "brightnessctl set 1%+";
          on-scroll-down = "brightnessctl set 1%-";
        };

        "hyprland/window" = {
          format = "󱂬 {title}";
          max-length = 50;
          separate-outputs = true;
        };

        "clock" = {
          format = "{:%Y-%m-%d %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "pulseaudio" = {
          format = "{icon} {volume}%";
          format-muted = "󰝟";
          format-icons = { default = ["󰕿" "󰖀" "󰕾"]; };
          on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
          on-click-right = "${pkgs.pamixer}/bin/pamixer -t";
        };

        "bluetooth" = {
          format = "󰂯";
          on-click = "${pkgs.overskride}/bin/overskride";
          on-click-right = "rfkill toggle bluetooth";
        };

        "battery" = {
          format = "{icon} {capacity}%";
          format-icons = ["" "" "" "" ""];
          on-click-right = "${pkgs.kitty}/bin/kitty -e ${pkgs.btop}/bin/btop";
        };

        "custom/power" = {
          format = "󰐥";
          on-click = "${pkgs.wlogout}/bin/wlogout";
        };
      };
    };

    style = ''
      * {
        border: none;
        font-family: "FiraCode Nerd Font", sans-serif;
        font-size: 13px;
      }

      window#waybar {
        /* Background color + transparency pulled from theme.json */
        background-color: rgba(13, 13, 13, ${toString theme.opacity}); 
        border-bottom: 2px solid ${theme.colors.accent};
        color: ${theme.colors.text};
      }

      #workspaces button {
        padding: 0 6px;
        min-width: 40px;
      }
      #workspaces button.active {
        color: ${theme.colors.accent};
        border-bottom: 2px solid ${theme.colors.accent};
      }
      #workspaces .workspace-label {
        font-size: 11px;
        opacity: 0.7;
        margin-left: 4px;
      }

      #window {
        padding: 0 10px;
      }
      #clock {
        color: ${theme.colors.accent};
        font-weight: bold;
      }

      #custom-power {
        color: ${theme.colors.critical};
        padding: 0 10px;
      }

      #clock, #cpu, #memory, #battery, #tray, #pulseaudio, #bluetooth, #backlight {
        padding: 0 10px;
        border-left: 1px solid ${theme.colors.border};
      }
    '';
  };
}
