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

## hyprpaper memory growth: drop the workaround when upstream fixes it

hyprpaper 0.8.4 (the current upstream release) caches every wallpaper image it
has loaded and never frees it. Because `goto-workspace` sets a wallpaper per
workspace, a session accumulates one decoded image per switch. After 3 days of
uptime hyprpaper held 759 MB (82 MB RSS + 715 MB swap) with a single 1920x1080
wallpaper configured.

`set-wallpaper` in `home/modules/hyprland.nix` works around this by running
`hyprctl hyprpaper unload all` before each load, so exactly one image stays
resident. `goto-workspace` and `pick-wallpaper` both go through it, so do not
call `hyprctl hyprpaper wallpaper` directly.

To confirm and clean up:

```bash
grep -E "VmRSS|VmSwap" /proc/$(pgrep -x hyprpaper)/status   # expect tens of MB, VmSwap 0
```

Switch wallpapers a few times on several workspaces. If RSS stays flat:

1. cut the body of `set-wallpaper` back to a plain `hyprctl hyprpaper wallpaper ",$WALL"`
2. delete this section
