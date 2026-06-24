{ pkgs, ... }: {
  home.packages = with pkgs; [
    steam-run
    mangohud
    prismlauncher
  ];
}
