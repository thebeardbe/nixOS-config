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
