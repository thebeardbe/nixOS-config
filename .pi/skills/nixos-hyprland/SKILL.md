---
name: nixos-hyprland
description: Expert knowledge of NixOS configuration, Hyprland window manager, and Hyprland Lua config API. Use when working with NixOS flakes, home-manager, hyprland config (both Lua and hyprlang), hyprlock, hypridle, hyprpaper, waybar, or any other hypr ecosystem component on NixOS. Also use for verifying new Hyprland configs, troubleshooting NixOS builds, and understanding this project's architecture.
---

# NixOS + Hyprland Expert Skill

Complete knowledge base for managing this NixOS configuration, with special focus on Hyprland and its Lua config API.

**Official references:**
- Hyprland wiki: `https://wiki.hypr.land/`
- Official example config: `github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua`
- NixOS wiki: `https://wiki.nixos.org/wiki/Hyprland`

## Quick Start

### Rebuild
```bash
# Rebuild and switch current machine
sudo nixos-rebuild switch --flake .#$(hostname)

# Or use the rebuild alias (on foxyNix):
rebuild

# Dry-run / test (doesn't make permanent):
sudo nixos-rebuild test --flake .#$(hostname)

# Verify config without building:
nix flake check
```

### Verify a new Hyprland config
```bash
# BEST: Use Hyprland's built-in validator (full API-aware check)
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
# Output: "config ok" if valid, or detailed errors if not

# Check Lua syntax (basic parse — no API context)
luajit -e 'local f,err=loadfile("/home/thebeardbe/.config/hypr/hyprland.lua"); if not f then print(err) else print("syntax ok") end'

# Check the deployed file
cat ~/.config/hypr/hyprland.lua

# Check runtime errors
hyprctl configerrors

# Dry-run build from repo root (~/nixos-config)
sudo nixos-rebuild dry-build --flake .#$(hostname)

# Check what files would change
nixos-rebuild dry-activate --flake .#$(hostname) 2>&1 | grep -E "^(activating|creating|removing|reloading)"
```

### Reload Hyprland config without rebuilding
```bash
# From within Hyprland:
hyprctl reload

# Or keybind: Super + Shift + R
```

## Project Architecture

See [REPO-MAP.md](../../REPO-MAP.md) for the full architecture guide. Key files for this skill:

| What | File |
|------|------|
| **Main Hyprland Lua config** | `home/files/hyprland.lua` → deploys to `~/.config/hypr/hyprland.lua` |
| **Host-specific Lua overrides** | `hosts/<host>/home/hypr-host.lua` → deploys to `~/.config/hypr/host.lua` |
| **Hyprland module (scripts)** | `home/modules/hyprland.nix` |
| **Hyprlock config** | `home/modules/hyprlock.nix` |
| **Hypridle config** | `home/modules/hypridle.nix` |
| **Waybar config** | `home/modules/waybar.nix` |
| **Hyprshell config** | `home/files/hyprshell-config.toml` |
| **Theme tokens** | `theme.json` |
| **User packages** | `home/packages.nix` |
| **Appearance (kitty, wofi, GTK)** | `home/modules/appearance.nix` |
| **Greeter (launches Hyprland)** | `common/configuration.nix` → `services.greetd` |
| **System-level Hyprland** | `common/configuration.nix` → `programs.hyprland` |
| **Flake entry point** | `flake.nix` |

## Config Format: Lua vs hyprlang

This project uses **Lua** (`hl.*` API) for Hyprland config, NOT hyprlang. This is critical:

- **Lua config path:** `~/.config/hypr/hyprland.lua` (deployed by home-manager from `home/files/hyprland.lua`)
- **How Hyprland loads it:** greetd launches `Hyprland -c /home/thebeardbe/.config/hypr/hyprland.lua`
- **Why Lua:** hyprshell 4.x uses `eval hl.dispatch(...)` IPC commands which require the Lua config manager to be active. hyprlang mode does NOT support this.
- **Host overrides:** `~/.config/hypr/host.lua` is loaded via `dofile()` in the main Lua config
- **home-manager hyprland module:** Left at `settings = { }` (empty) — the real config is Lua, not hyprlang. The module only provides systemd integration.

### When adding new config to Hyprland

Always use the Lua API (`hl.*` functions), NEVER hyprlang syntax. See [Hyprland Lua API Reference](references/hyprland-lua-api.md) for the complete API.

To add a new feature:
1. Edit `home/files/hyprland.lua`
2. Add your Lua code using the `hl.*` API
3. Rebuild: `sudo nixos-rebuild switch --flake .#$(hostname)`
4. Or just reload: `hyprctl reload` (for most config changes)

## Hyprland Lua API Quick Reference

See [full API reference](references/hyprland-lua-api.md). Common patterns:

```lua
-- Keybinds
hl.bind("SUPER + K", hl.dsp.exec_cmd("kitty"))              -- Launch app
hl.bind("SUPER + C", hl.dsp.window.close())                  -- Close window
hl.bind("SUPER + V", hl.dsp.window.float({action="toggle"})) -- Toggle float
hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock"))            -- Lock screen
hl.bind("SUPER + left", hl.dsp.focus({direction="left"}))    -- Move focus
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), {mouse=true})  -- Mouse drag

-- Workspace switching (with wallpaper script)
hl.bind("SUPER + 1", hl.dsp.exec_cmd("goto-workspace 1"))
hl.bind("SUPER + SHIFT + 1", hl.dsp.window.move({workspace = 1}))

-- Appearance
hl.config({
    general = { gaps_in = 5, gaps_out = 10, border_size = 2,
        col = { active_border = { colors = {"rgba(0abdc6ff)"} },
                inactive_border = "rgba(000b1eaa)" } },
    decoration = { rounding = 10, active_opacity = 0.95, blur = { enabled = true, size = 3, passes = 1 } },
})

-- Animations
hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })

-- Window rules
hl.window_rule({ match = { class = "kitty" }, workspace = "1" })
hl.window_rule({ name = "no-focus", match = { class = "^$", xwayland = true }, no_focus = true })

-- Autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("kitty")
    hl.exec_cmd("hyprpaper")
end)
```

## Verifying New Configurations

### Step 1: Check Lua Syntax
```bash
# From repo root, check the source file
lua -e 'dofile("home/files/hyprland.lua")'

# Or check the deployed file
lua -e 'dofile("/home/thebeardbe/.config/hypr/hyprland.lua")'
```

### Step 2: Dry-build NixOS
```bash
sudo nixos-rebuild dry-build --flake .#$(hostname)
```
This catches Nix evaluation errors without building everything.

### Step 3: Check for common issues
- Duplicate keybinds (two binds for same key combo)
- Missing scripts referenced in `hl.dsp.exec_cmd()`
- Host overrides that conflict with main config
- Theme color references (ensure `theme.json` has all referenced colors)

### Step 4: Test in-place reload (for Hyprland-only changes)
```bash
hyprctl reload
```
Most appearance, keybind, and animation changes take effect with `hyprctl reload`. Only new packages/scripts require a full rebuild.

## Common Tasks

### Add a new Hyprland keybind
Edit `home/files/hyprland.lua`, add to the keybinds section:
```lua
hl.bind("SUPER + T", hl.dsp.exec_cmd("your-command"))
```

### Change the theme
Edit `theme.json`, rebuild. This updates: Waybar, Kitty, Wofi, Hyprlock, Starship, GTK/Qt.

### Add a new wallpaper
1. Drop image in `~/Pictures/Wallpapers/`
2. Pick it with `Super + Shift + W` (pick-wallpaper script)
3. Optionally add to repo's `wallpapers/` directory

### Add a new host
1. Create `hosts/<hostname>/` with `default.nix`, `hardware-configuration.nix`, `system/`, `home/`
2. Add to `flake.nix` → `nixosConfigurations.<hostname> = mkHost "<hostname>";`
3. Generate hardware config: `nixos-generate-config --root /mnt` (on the target machine)

### Fix a broken Hyprland config
If Hyprland won't start after a config change:
1. Switch to TTY: `Ctrl+Alt+F2`
2. Log in as thebeardbe
3. Edit: `vim ~/.config/hypr/hyprland.lua` (fix the issue)
4. Or restore from repo: `cp ~/nixos-config/home/files/hyprland.lua ~/.config/hypr/hyprland.lua`
5. Rebuild: `sudo nixos-rebuild switch --flake ~/nixos-config#$(hostname)`

## NixOS Patterns Used in This Config

See [NixOS Patterns Reference](references/nixos-patterns.md) for details on:
- Flake inputs/outputs pattern
- home-manager as NixOS module
- `specialArgs` / `extraSpecialArgs` for passing theme/config
- Optional flake inputs (nix-secrets)
- Module system (imports, options, config)
- Package overrides and unstable channel

## Troubleshooting

See [Troubleshooting Guide](references/troubleshooting.md) for common issues:
- Hyprland won't start / black screen
- Lua config parse errors
- hyprshell window switcher not working
- Waybar not showing modules
- hyprlock stacking multiple instances
- Theme changes not applying
- Nix build failures
- greetd / greeter issues
