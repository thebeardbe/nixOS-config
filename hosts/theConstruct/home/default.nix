{ lib, pkgs, ... }: {
  imports = [
    ./packages.nix
  ];

  # Smaller GTK font for the ultrawide (affects Firefox UI, etc.)
  gtk.font = lib.mkForce {
    name = "FiraCode Nerd Font";
    size = 10;
  };

  # Smaller kitty font on the big ultrawide
  programs.kitty.font.size = lib.mkForce 9;
  programs.waybar.settings.mainBar.modules-right = lib.mkForce [
    "pulseaudio" "cpu" "memory" "tray" "custom/notification" "custom/power"
  ];

  # Local llama.cpp router on port 21434, which only runs on this host. The
  # "pi" coding agent picks this up for its built-in llama.cpp provider, so
  # /llama and /model can reach the local server without /login. The server
  # requires the API key from ~/.config/llama/api-key; the agent keeps its own
  # copy of that credential in ~/.pi/agent/auth.json, so nothing is set here.
  home.sessionVariables.LLAMA_BASE_URL = "http://127.0.0.1:21434";

  # The compose stack and its presets only make sense on this host: the GPU
  # device and the model directory are local to it, so they must not be linked
  # into the laptop's home.
  home.file.".config/llama/compose.yaml".source = ../../../home/files/llama/compose.yaml;
  home.file.".config/llama/models.ini".source = ../../../home/files/llama/models.ini;

  # API key for the local llama.cpp server. Created once, here, so a rebuild
  # never rotates a key a client has already stored; the value lives only in
  # this file and is never committed or copied into the Nix store. 0600, drawn
  # from the system CSPRNG. Rotation is documented in the compose file's mount
  # comment.
  home.activation.generateLlamaApiKey = pkgs.lib.mkAfter ''
    keyFile="$HOME/.config/llama/api-key"
    if [ ! -e "$keyFile" ]; then
      mkdir -p "$HOME/.config/llama"
      umask 077
      head -c 48 /dev/urandom | base64 | tr -d '\n' > "$keyFile"
      chmod 600 "$keyFile"
    fi
  '';

  # Host-specific Hyprland Lua config (monitors, workspace assignments)
  home.file.".config/hypr/host.lua".source = ./hypr-host.lua;
}
