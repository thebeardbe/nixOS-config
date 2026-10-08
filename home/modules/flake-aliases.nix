# Shared flake aliases — defined once and assigned to both shells so bash and
# zsh can never drift apart. Imported from home/home.nix.
{ ... }:
let
  # The checkout directory is not named consistently across hosts: the GitHub
  # repo is "nixOS-config" while foxyNix has it cloned as "nixos-config".
  # Resolve it at shell runtime so every alias works on both hosts from this one
  # definition. The `conf` aliases in home.nix and starship.nix call the same
  # helper.
  repoResolver = ''
    nixos-config-dir() {
      local candidate
      for candidate in "$HOME/nixOS-config" "$HOME/nixos-config"; do
        if [ -d "$candidate" ]; then
          printf '%s' "$candidate"
          return 0
        fi
      done
      printf '%s\n' "error: no nixOS-config checkout found in $HOME" >&2
      return 1
    }
  '';
  repo = "\"$(nixos-config-dir)\"";
  # `git add -A` puts new files in the index so the flake can see them; this is
  # safe because .gitignore keeps secrets and scratch files out of git.
  rebuild = "pushd ${repo} && git add -A && sudo nixos-rebuild switch --flake .#$(hostname) && popd";
  # Same commit behaviour as systemd.services.nix-flake-update: commit only
  # flake.lock, and only when it actually changed.
  update = "pushd ${repo} && nix flake update && { git diff --quiet -- flake.lock || git commit -m 'chore: flake update' -- flake.lock; } && sudo nixos-rebuild switch --flake .#$(hostname) && popd";
in
{
  programs.bash.initExtra = repoResolver;
  programs.zsh.initContent = repoResolver;
  programs.bash.shellAliases = { inherit rebuild update; };
  programs.zsh.shellAliases = { inherit rebuild update; };
}
