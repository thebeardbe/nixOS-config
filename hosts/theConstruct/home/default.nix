{ lib, pkgs, ... }: {
  imports = [
    ./packages.nix
  ];

  # Key path for the sellars entries declared in the shared home/home.nix. The
  # dedicated key was generated on this host and authorized for both the git
  # service (port 2222) and the shell (port 22), see
  # ~/Documents/agent-notes/homelab/git-server.md. The path is host-local state,
  # which is why it is set here and not in the shared module.
  programs.ssh.settings = {
    "sellars-git".identityFile = "~/.ssh/sellars";
    "sellars".identityFile = "~/.ssh/sellars";
  };

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

    # Web UI defaults: pre-fill the UI's API key so the browser never prompts.
    # Rewritten on every activation so it can never drift from the key (rotation
    # means deleting the key and rebuilding). Mounted read-only by the compose
    # file as --ui-config-file, which keeps the value out of the process table
    # and out of `docker inspect`, unlike an inline --ui-config.
    mkdir -p "$HOME/.config/llama"
    printf '{"apiKey":"%s"}\n' "$(cat "$keyFile")" > "$HOME/.config/llama/ui-config.json"
    chmod 600 "$HOME/.config/llama/ui-config.json"
  '';

  # Host-specific Hyprland Lua config (monitors, workspace assignments)
  home.file.".config/hypr/host.lua".source = ./hypr-host.lua;
}
