{ pkgs, theme, ... }:

{
  programs.starship = {
    enable = true;
    # Activeer integratie voor beide shells
    enableBashIntegration = true;
    enableZshIntegration = true;

    settings = {
      format = "$username$hostname$directory$git_branch$git_status$time$line_break$character";

      username = {
        style_user = "white bold";
        style_root = "black bold";
        format = "[$user]($style)";
        disabled = false;
        show_always = true;
      };

      hostname = {
        ssh_only = false;
        format = "@[$hostname](bold yellow) ";
        disabled = false;
      };

      directory = {
        truncation_length = 0;
        truncate_to_repo = false;
        style = "bold cyan";
        format = "in [$path]($style)[$read_only]($read_only_style) ";
      };

      git_branch = {
        symbol = " ";
        format = "on [$symbol$branch]($style) ";
      };

      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
	conflicted = "=";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
        untracked = "?";
        stashed = "$";
        modified = "!";
        staged = "+";
        renamed = "»";
        deleted = "✘";
      };

      time = {
        disabled = false;
        time_format = "%Y-%m-%d %R";
        style = "bold blue";
        format = "at [$time]($style) ";
      };

      character = {
        success_symbol = "[➜](bold ${theme.colors.accent})";
        error_symbol = "[➜](bold ${theme.colors.critical})";
      };
    };
  };
  # Configureer Zsh direct in deze module voor een complete shell-ervaring
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      rebuild = "pushd ~/nixos-config && git add . && sudo nixos-rebuild switch --flake .#foxyNix && popd";
      v = "nvim";
      conf = "cd ~/nixos-config && v";
      ls = "${pkgs.eza}/bin/eza --icons";
      cat = "${pkgs.bat}/bin/bat";
    };
    
    # Zorg dat de prompt altijd clean start
    initExtra = ''
      # Optionele extra Zsh instellingen
      bindkey '^[[1;5C' forward-word
      bindkey '^[[1;5D' backward-word
    '';
  };
}
