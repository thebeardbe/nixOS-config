{ pkgs, ... }:

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
        modules-center = [ "clock" ];
        modules-right = [ "cpu" "memory" "battery" "tray" ];

        "hyprland/workspaces" = {
	  disable-scroll = true;
	  all-outputs = true;
          format = "{icon}";
          on-click = "activate";
        };

	"tray" = {
	  icon-size = 18;
	  spacig = 10;
	};

        "clock" = {
          # Jouw vertrouwde ISO-achtige format voor 'time awareness'
          format = "{:%Y-%m-%d %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };

        "cpu" = {
          format = "CPU: {usage}%";
          interval = 5;
        };

        "memory" = {
          format = "RAM: {}%";
          interval = 5;
        };

        "battery" = {
          format = "{icon} {capacity}%";
          format-icons = ["" "" "" "" ""];
        };
      };
    };
    # Minimale styling voor een clean look
    style = ''
      * {
          border: none;
          font-family: "FiraCode Nerd Font", Roboto, Helvetica, Arial, sans-serif;
          font-size: 13px;
	  min-height: 0;
      }
      window#waybar {
          background-color: rgba(26, 27, 38, 0.85);
	  border-bottom: 2px solid rgba(100, 255, 218, 0.2);
          color: #c0caf5;
	  transition-property: background-color;
	  transition-duration: .5s;
      }
      #workspaces button {
          padding: 0 5px;
	  background-color: transparent;
          color: #c0caf5;
      }
      #workspaces button.active {
          color: #7aa2f7;
          border-bottom: 2px solid #7aa2f7;
      }
      #workspaces button.urgent {
	  color: #f7768e;
      }
      #clock, #cpu, #memory, #battery, #tray {
	  padding: 0 10px;
	  margin: 4px 0;
	  border-left: 1px solid rgba(187, 154, 247, 0.3);
      }
      #clock {
	  color: #7aa2f7;
	  font-weight: bold;
      }
      #tray {
	  border-left: none;
      }
    '';
  };
}
