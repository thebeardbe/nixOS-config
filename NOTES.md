# NOTES

Deferred work and things to revisit. Remove an item once it is resolved.

## Waybar overlay — remove when nixpkgs ships waybar >= 0.16

`overlays/waybar-lua.nix` pins Waybar to upstream commit `4e207a0` because the
packaged 0.15.0 dispatches workspace switches with Hyprland's legacy IPC form
(`dispatch workspace <n>`), which the Lua config manager rejects — so clicking a
workspace in the bar, or scrolling on it, does nothing.

The overlay is version-gated (`lib.versionOlder super.waybar.version "0.16"`), so
it stops applying automatically once nixpkgs provides a newer Waybar.

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
