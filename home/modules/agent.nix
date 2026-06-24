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

  # Deploy pi config files on first install only
  home.activation.setupPiConfig = pkgs.lib.mkAfter ''
    mkdir -p "$HOME/.pi/agent"
    
    if [ ! -f "$HOME/.pi/agent/settings.json" ]; then
      cp ${../files/agent/settings.json} "$HOME/.pi/agent/settings.json"
    fi

    ${if mySecrets.piAuth != null then ''
      if [ ! -f "$HOME/.pi/agent/auth.json" ]; then
        cat > "$HOME/.pi/agent/auth.json" << 'EOF'
${mySecrets.piAuth}
EOF
        chmod 600 "$HOME/.pi/agent/auth.json"
      fi
    '' else ""}
  '';
}
