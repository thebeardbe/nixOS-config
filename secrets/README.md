# Private secrets repo — host on your Proxmox git server
#
# Structure for the private nix-secrets flake:
#
# nix-secrets/
# ├── flake.nix
# ├── common/
# │   └── shared.nix          # Secrets shared across all hosts
# └── hosts/
#     ├── foxyNix/
#     │   └── agent.nix        # pi-coding-agent auth.json
#     └── theConstruct/
#         └── agent.nix
#
# The public flake imports these via:
#   nix-secrets = {
#     url = "git+ssh://git@your-server/filip/nix-secrets";
#     flake = true;
#   };
#
# Each secret module sets mySecrets.<name> options.
# Example agent.nix:
#
#   { ... }: {
#     mySecrets.piAuth = builtins.readFile ./auth.json;
#   };
