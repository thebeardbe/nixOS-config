# Waybar from upstream master.
#
# Why: nixpkgs ships Waybar 0.15.0, which dispatches workspace switches through
# Hyprland's *legacy* IPC form (`dispatch workspace <n>`). Hyprland's Lua config
# manager rejects every legacy dispatcher, so clicking a workspace in the bar
# (and scroll-to-switch) silently does nothing.
#
# Upstream added Lua-aware dispatch in `IPC::dispatch` / `buildLuaDispatch`
# (Hyprland IPC: detected Lua-based dispatch protocol). It is unreleased as of
# 0.15.0, so we pin the commit that introduced it.
#
# Version-gated: once nixpkgs ships waybar >= 0.16 this overlay stops applying on
# its own. Then delete this file, the overlay entry in flake.nix, and the note in
# NOTES.md. Verify with:
#   nix eval --raw .#nixosConfigurations.theConstruct.pkgs.waybar.version
self: super:
let
  lib = super.lib;
in
{
  waybar =
    if lib.versionOlder super.waybar.version "0.16" then
      # `runTests = false` (not just `doCheck`) so meson drops `-Dtests=` too;
      # otherwise the configure step still demands catch2 at build time.
      (super.waybar.override { runTests = false; }).overrideAttrs (old: {
        version = "0.15.0-unstable-2026-10-18";
        src = super.fetchFromGitHub {
          owner = "Alexays";
          repo = "Waybar";
          rev = "4e207a0cb51a9eb89b4245d90245721f5e39bf06";
          hash = "sha256-0L1elPWYo9yKgEwpXWWVWQyPVU0SW36LkWUR26CksgU=";
        };
        # Master drift vs the 0.15.0 recipe:
        #  - `wwan` (mm-glib) now defaults to enabled
        #  - `cava` now wants an external libcava subproject (auto-download off)
        # Neither module is used here, so both are disabled rather than pulled in.
        mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dwwan=disabled" "-Dcava=disabled" ];
        # Master still reports `Waybar v0.15.0`, so the version hook cannot match.
        doInstallCheck = false;
        # Why tests are off (see `runTests = false` above): upstream's
        # `SleeperThread control flags ...` test spawns a subprocess through a
        # hardcoded `bash-interactive` path that is not in the build closure, so
        # it always fails inside the Nix sandbox ("execl(.../bin/sh) failed in
        # forkExec: No such file or directory"). Upstream test bug, not a
        # Waybar defect. Revisit when the overlay goes away (waybar >= 0.16).
      })
    else
      super.waybar;
}
