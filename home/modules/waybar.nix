{ pkgs, theme, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 4;
        modules-left = [ "hyprland/workspaces" "hyprland/mode" ];
        modules-center = [ "hyprland/window" "clock" ];
        modules-right = [ "pulseaudio" "bluetooth" "cpu" "memory" "battery" "tray" "custom/power" ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          on-click = "activate";
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
        };

        "bluetooth" = {
          format = "󰂯";
          on-click = "${pkgs.overskride}/bin/overskride";
        };

        "battery" = {
          format = "{icon} {capacity}%";
          format-icons = ["" "" "" "" ""];
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
        /* Hier koppelen we de achtergrondkleur EN de transparantie uit de JSON */
        background-color: rgba(13, 13, 13, ${toString theme.opacity}); 
        border-bottom: 2px solid ${theme.colors.accent};
        color: ${theme.colors.text};
      }

      #workspaces button.active {
        color: ${theme.colors.accent};
        border-bottom: 2px solid ${theme.colors.accent};
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

      #clock, #cpu, #memory, #battery, #tray, #pulseaudio, #bluetooth {
        padding: 0 10px;
        border-left: 1px solid ${theme.colors.border}; /* 4d = 30% opacity */
      }
    '';
  };
}
