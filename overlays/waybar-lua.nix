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
      super.waybar.overrideAttrs (old: {
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
      })
    else
      super.waybar;
}
