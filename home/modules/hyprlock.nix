{ theme, ... }:

{
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading = true;
        hide_cursor = true;
      };

      background = [
        {
          path = "screenshot"; # Neemt een screenshot van je huidige scherm
          blur_passes = 2;
          color = "rgba(26, 27, 38, 0.8)";
        }
      ];

      input-field = [
        {
          size = "200, 50";
          position = "0, -80";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          font_color = "rgb(${theme.colors.text})";
          inner_color = "rgb(${theme.colors.background})";
          outer_color = "rgb(${theme.colors.accent})";
          outline_thickness = 2;
          placeholder_text = "Password...";
          shadow_passes = 2;
        }
      ];

      label = [
        {
          monitor = "";
          text = "$TIME";
          color = "rgb(${theme.colors.text})";
          font_size = 64;
          font_family = "FiraCode Nerd Font bold";
          position = "0, 80";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
