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
    NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  };

  # settings.json — always deployed from repo (identical on all machines)
  home.file.".pi/agent/settings.json" = {
    source = ../files/agent/settings.json;
    force = true;
  };

  # --- pi agent configuration ---
  # Everything under ../files/agent is deployed into ~/.pi/agent by home-manager.
  # force = true replaces the existing regular files/directories with store
  # symlinks on machines where the agent already created them.
  home.file = {
    ".pi/agent/AGENTS.md" = {
      source = ../files/agent/AGENTS.md;
      force = true;
    };
    ".pi/agent/README.md" = {
      source = ../files/agent/README.md;
      force = true;
    };
    ".pi/agent/agents" = {
      source = ../files/agent/agents;
      force = true;
    };
    ".pi/agent/extensions" = {
      source = ../files/agent/extensions;
      force = true;
    };
    ".pi/agent/prompts" = {
      source = ../files/agent/prompts;
      force = true;
    };
    ".pi/agent/skills" = {
      source = ../files/agent/skills;
      force = true;
    };
    ".pi/agent/tests" = {
      source = ../files/agent/tests;
      force = true;
    };
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

    # Set npm prefix so global installs go to ~/.npm-global
    mkdir -p "$HOME/.npm-global"
    npm config set prefix "$HOME/.npm-global" 2>/dev/null || true
  '';
}
