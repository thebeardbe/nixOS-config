{ pkgs, theme, ... }:

{
  programs.starship = {
    enable = true;
    # Enable shell integration for both bash and zsh
    enableBashIntegration = true;
    enableZshIntegration = true;

    settings = {
      # Full prompt format: user@hostname in directory on git-branch [git-status] at time
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
        format = "@[$hostname](bold ${theme.colors.text}) ";
        disabled = false;
      };

      directory = {
        truncation_length = 0;
        truncate_to_repo = false;
        style = "bold ${theme.colors.accent}";
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

  # Zsh configuration — the primary interactive shell
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
    
    # Extra initialization — runs after starship prompt setup
    initContent = ''
      # Ctrl+Left/Right to jump words in zsh
      bindkey '^[[1;5C' forward-word
      bindkey '^[[1;5D' backward-word
    '';
  };
}
