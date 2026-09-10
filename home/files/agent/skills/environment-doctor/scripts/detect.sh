#!/usr/bin/env bash
# environment-doctor: detect common setup hazards before they waste a session.
# Read-only. Always exits 0.
set -uo pipefail
DIR="${1:-.}"
[ -d "$DIR" ] && cd "$DIR" 2>/dev/null

echo "environment-doctor - $(pwd)"

hdr() { printf '\n== %s ==\n' "$1"; }

hdr "Filesystem type (exfat/NTFS break symlinks, nix builds, venvs)"
FS=$(df -T . 2>/dev/null | awk 'NR==2{print $2}')
echo "  $FS  ($(df -h . 2>/dev/null | awk 'NR==2{print $1" "$6}'))"
case "$FS" in
  exfat|vfat|ntfs|fuseblk)
    echo "  WARNING: no symlinks/POSIX perms. nix build, python venv, and"
    echo "  node_modules bin links will fail or be faked. Prefer an ext4 dir."
    ln -s /tmp ./.envdoctor-symtest 2>/dev/null && { echo "  symlink: OK"; rm -f ./.envdoctor-symtest; } || echo "  symlink: DENIED (confirmed)"
    ;;
  ext4|xfs|btrfs|zfs|apfs) echo "  symlink: OK (POSIX fs)" ;;
esac

hdr "Toolchain presence"
for t in git rg jq node npm python3 pip3 uv go cargo make just nix nix-shell direnv ssh-add setsid sudo docker; do
  if command -v "$t" >/dev/null 2>&1; then printf '  %-10s %s\n' "$t" "$(command -v "$t")"; fi
done

hdr "Missing but commonly assumed"
for t in python3 node make; do
  command -v "$t" >/dev/null 2>&1 || echo "  MISSING: $t"
done

hdr "Project dev environment"
for f in shell.nix flake.nix .envrc devenv.nix Makefile justfile package.json pyproject.toml requirements.txt go.mod Cargo.toml docker-compose.yml compose.yaml; do
  [ -e "$f" ] && echo "  present: $f"
done
if [ -f .envrc ]; then echo "  direnv: $(command -v direnv >/dev/null 2>&1 && echo available || echo 'MISSING direnv')"; fi

hdr "Git state"
if git rev-parse --git-dir >/dev/null 2>&1; then
  echo "  branch: $(git branch --show-current 2>/dev/null)"
  echo "  dirty : $(git status --porcelain 2>/dev/null | wc -l) path(s)"
  git status --porcelain 2>/dev/null | head -10 | sed 's/^/    /'
  echo "  remote: $(git remote get-url origin 2>/dev/null || echo none)"
else
  echo "  (not a git repo)"
fi

hdr "Secret hygiene"
for f in .env .env.local secrets.json; do
  [ -e "$f" ] && { git check-ignore -q "$f" 2>/dev/null && echo "  $f exists, ignored OK" || echo "  WARNING: $f exists and is NOT gitignored"; }
done

echo
echo "Fix the WARNING lines before starting; they cause repeat failures."
