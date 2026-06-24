{ config, pkgs, ... }:

let
  inherit (config) mySecrets;
in
{
  home.packages = with pkgs; [
    nodejs
  ];

  home.sessionVariables = {
    PATH = "$HOME/.npm-global/bin:$PATH";
  };

  # settings.json — always deployed from repo (identical on all machines)
  home.file.".pi/agent/settings.json" = {
    source = ../files/agent/settings.json;
    force = true;
  };

  # auth.json — only deployed on first install (per-machine secrets)
  home.activation.setupPiAuth = pkgs.lib.mkAfter ''
    ${if mySecrets.piAuth != null then ''
      if [ ! -f "$HOME/.pi/agent/auth.json" ]; then
        mkdir -p "$HOME/.pi/agent"
        cat > "$HOME/.pi/agent/auth.json" << 'EOF'
${mySecrets.piAuth}
EOF
        chmod 600 "$HOME/.pi/agent/auth.json"
      fi
    '' else ""}
  '';
}
