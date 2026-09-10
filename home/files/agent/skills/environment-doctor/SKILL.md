---
name: environment-doctor
description: Diagnose a broken or surprising project environment before working in it. Covers missing runtimes, exfat/NTFS mounts that break symlinks and nix builds, missing dev shells, dirty git state, and un-ignored secrets. Use when commands fail oddly, setup feels hacky, or at the start of work in an unfamiliar repo.
---

# Environment Doctor

Run this when a tool "should exist" but does not, when `nix build`, a Python
venv, or `npm install` fails mysteriously, or before starting in a new repo.

## 1. Run the check

```bash
bash "$HOME/.pi/agent/skills/environment-doctor/scripts/detect.sh" .
```

It reports: filesystem type, symlink support, installed tools, missing common
tools, project dev-environment files, git state, and un-ignored secret files.

## 2. Interpret

- **exfat / vfat / NTFS / fuseblk mount**: no real symlinks or POSIX perms.
  This breaks `nix build` (`result` symlink denied), Python venvs, and
  `node_modules/.bin`. Recommendation: move active repos to an ext4 path
  (`~/Projects`, `/home`) and keep the removable drive for storage/backups.
- **`python3` missing**: use the project's `shell.nix` / `flake.nix` /
  `package.json` script, and add `direnv` + `.envrc` (`use nix`) so plain
  `python3` and `pytest` work. Do not wrap every command in a fresh ad-hoc
  `nix-shell -p` invocation; enter the shell once.
- **No dev shell but a runtime is needed**: propose adding one (small
  `shell.nix` + `.envrc`) rather than improvising per command.
- **`.env` present and not gitignored**: add it to `.gitignore` immediately.
- **Dirty tree before starting**: inspect, commit or stash deliberately; do not
  build on top of unknown changes.

## 3. Report and fix

Give the user:

1. what is wrong (with the command output that shows it),
2. which failures it explains,
3. the smallest fix (move repo, add `.envrc`, add `.gitignore` entry),
4. ask before doing anything that moves data or changes system config.

Do not silently work around a broken environment for the whole session;
surface it once and fix it (or get agreement to defer).
