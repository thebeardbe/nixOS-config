# Shared flake aliases — defined once and assigned to both shells so bash and
# zsh can never drift apart. Imported from home/home.nix.
{ ... }:
let
  repo = "~/nixOS-config";
  # `git add -A` puts new files in the index so the flake can see them; this is
  # safe because .gitignore keeps secrets and scratch files out of git.
  rebuild = "pushd ${repo} && git add -A && sudo nixos-rebuild switch --flake .#$(hostname) && popd";
  # Same commit behaviour as systemd.services.nix-flake-update: commit only
  # flake.lock, and only when it actually changed.
  update = "pushd ${repo} && nix flake update && { git diff --quiet -- flake.lock || git commit -m 'chore: flake update' -- flake.lock; } && sudo nixos-rebuild switch --flake .#$(hostname) && popd";
in
{
  programs.bash.shellAliases = { inherit rebuild update; };
  programs.zsh.shellAliases = { inherit rebuild update; };
}
