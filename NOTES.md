# NOTES

Deferred work and things to revisit. Remove an item once it is resolved.

## Declare the sellars key path on foxyNix

The sellars SSH entries live in the shared `home/home.nix` with `hostname`, `user`
and `port` only; `identityFile` moved to each host's home config, because a key
path is local state on one machine. theConstruct declares `~/.ssh/sellars`.

foxyNix declares nothing yet: it reaches sellars with its own key (authorized on
the server as `thebeardbe@foxyNix->sellars`), but that file's name on this machine
was never recorded, so guessing a path would risk a config that points at nothing.
Until it is set, `ssh sellars` on foxyNix falls back to the agent and the default
`~/.ssh/id_*` names, then to a password prompt, so nothing is broken, just
unconfigured.

To resolve, on foxyNix find the key whose public comment matches:

```bash
grep -l 'foxyNix->sellars' ~/.ssh/*.pub
```

Then add to `hosts/foxyNix/home/default.nix`, replacing the comment there:

```nix
programs.ssh.settings = {
  "sellars-git".identityFile = "~/.ssh/<that file>";
  "sellars".identityFile = "~/.ssh/<that file>";
};
```

Verify with `ssh -G sellars | grep identityfile` and `ssh sellars hostname`.

## Waybar overlay — remove when nixpkgs ships waybar >= 0.16

`overlays/waybar-lua.nix` pins Waybar to upstream commit `4e207a0` because the
packaged 0.15.0 dispatches workspace switches with Hyprland's legacy IPC form
(`dispatch workspace <n>`), which the Lua config manager rejects — so clicking a
workspace in the bar, or scrolling on it, does nothing.

The overlay is version-gated (`lib.versionOlder super.waybar.version "0.16"`), so
it stops applying automatically once nixpkgs provides a newer Waybar.

The overlay also builds Waybar with `runTests = false`: upstream's
`SleeperThread control flags are stable under concurrent wake and stop` test
execs a hardcoded `bash-interactive` path that is not part of the build closure,
so the suite always fails inside the Nix sandbox. That is an upstream test bug,
not a Waybar defect; the flag disappears together with this overlay.

To confirm and clean up:

```bash
nix eval --raw .#nixosConfigurations.theConstruct.pkgs.waybar.version   # expect >= 0.16
```

Then click a workspace in the bar. If it switches:

1. delete `overlays/waybar-lua.nix`
2. delete the `nixpkgs.overlays` entry in `flake.nix`
3. delete this section

## hyprpaper 0.8.x: per-output wallpapers, and a stale daemon hides upgrades

hyprpaper 0.8 dropped the old config keys and IPC. There is no `preload` key, and
`wallpaper = ,<path>` with an empty monitor matches no output, so it logs `Monitor
<name> has no target: no wp will be created` and applies nothing. `hyprctl
hyprpaper` now accepts only `wallpaper <monitor>,<path>` and `listactive`;
`preload`, `unload` and `listloaded` return "invalid hyprpaper request".

`set-wallpaper` in `home/modules/hyprland.nix` therefore applies the image once
per output, enumerated from `hyprctl monitors -j`, and the Lua autostart,
`goto-workspace` and `pick-wallpaper` all go through it. `hyprpaper.conf` is down
to `splash` only.

Related trap worth remembering: a daemon started before a flake update keeps
running the OLD binary, so its own config keys and IPC still work and the upgrade
stays invisible until the process is restarted. A 0.7-era hyprpaper had been up
for 3 days and 759 MB (82 MB RSS + 715 MB swap) before a restart exposed all of
the above as a regression.

To verify per-workspace switching:

```bash
hyprctl hyprpaper listactive   # must name the path expected for that workspace
```

## Umbriel trial: nested only, not yet a session

`home/modules/umbriel.nix` installs Umbriel and `trial-umbriel`, and deploys
`home/files/umbriel/config.toml` (keybinds mirroring `home/files/hyprland.lua`).
The config is validated at build time by Umbriel's own validator, so a bad
keybind fails the rebuild.

Measured on theConstruct 2026-11-08, nested under Hyprland via
`WLR_BACKENDS=wayland`: the whole compositor sits at ~174 MiB RSS versus
Hyprland's ~220 MiB, with blur and shadows disabled. Nested mode sets `Mod` to
Alt automatically, which is why the trial cannot collide with Hyprland's Super
binds. It tracked a real client (`umbriel windows` showed a tiled kitty) and
reported dwindle workspaces, so compositing is verified, not just started.

Umbriel's docs show action arguments space-separated (`submap resize`), but this
build requires a colon (`submap:resize`, `window-modify-primary-extent:-0.02`)
and silently drops the binds otherwise. Trust `umbriel msg --help` over the
docs, and keep the build-time validation.

Still open, when the trial graduates to a real session: a `wayland-sessions`
entry for this Hyprland Lua config, tuigreet session selection (tuigreet can list
sessions itself, so the Noctalia greeter is optional), `pick-wallpaper` needs an
Umbriel equivalent because it drives hyprpaper, and Hyprland's `pseudo` has no
Umbriel counterpart.

Unrelated but found here: `hyprshot -m output` hung for ten minutes on
theConstruct and had to be killed. Worth checking against the Super+Print bind.

