{ theme, ... }:

let
  # Helper to remove # for hyprlock colors
  hex = color: builtins.substring 1 6 color;
in
{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading = true;
        hide_cursor = true;
        grace = 0;
        no_fade_in = false;
      };

      background = [
        {
          path = "screenshot"; # VR simulation background
          blur_passes = 3;
          blur_size = 5;
          color = "rgb(${hex theme.colors.background})";
        }
      ];

      input-field = [
        {
          size = "250, 60";
          position = "0, -120";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(${hex theme.colors.text})";
          inner_color = "rgb(${hex theme.colors.background})";
          outer_color = "rgb(${hex theme.colors.accent})";
          outline_thickness = 3;
          placeholder_text = "<span foreground='#${hex theme.colors.accent}'>ACCESSING THE NET...</span>";
          shadow_passes = 3;
        }
      ];

      label = [
        {
          monitor = "";
          text = "OTHERLAND: $TIME";
          color = "rgb(${hex theme.colors.text})";
          font_size = 72;
          font_family = "${theme.font.family} bold";
          position = "0, 100";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
        }
        {
          monitor = "";
          text = "SIMULATION LEVEL: STABLE";
          color = "rgb(${hex theme.colors.accent})";
          font_size = 14;
          font_family = "${theme.font.family}";
          position = "0, 20";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
