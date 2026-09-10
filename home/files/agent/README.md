# pi agent configuration

This directory is the declarative source for everything under `~/.pi/agent/`.

Home-manager deploys it via `home/modules/agent.nix`, which links each file and
configuration directory here into `~/.pi/agent/` as read-only Nix store
symlinks. The same configuration is applied to every host because the module is
imported by the shared `home/home.nix`.

## Making changes

Edit the files in this repository, then apply them with a rebuild. The
`rebuild` alias must be run from `/home/thebeardbe/nixOS-config`:

```
cd /home/thebeardbe/nixOS-config
rebuild
```

On the first activation, home-manager moves any pre-existing real file or
directory under `~/.pi/agent/` to a copy with the `.hm-backup` suffix before
creating the symlink. Those backups are safe to delete once the switch has been
applied.

Do not edit the live copies under `~/.pi/agent/` directly. They are symlinks
into the Nix store, and the next rebuild overwrites any local change.

## Runtime state is intentionally unmanaged

The following paths stay writable on each machine and are deliberately not
copied into this repository or linked by home-manager:

- `sessions/` — per-machine agent session history
- `npm/` — npm runtime cache and prefix
- `git/` — pi runtime git data
- `auth.json` — per-machine credentials
- `models-store.json` — per-machine model state
- `trust.json` — per-machine trust state

Add a file or directory to `home/modules/agent.nix` only when it is
configuration that should be identical across hosts.
