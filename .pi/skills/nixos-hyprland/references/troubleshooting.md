# Troubleshooting Guide

Common issues encountered in this NixOS + Hyprland setup and how to fix them.

## Hyprland Won't Start / Black Screen

### Lua config parse error
**Symptom:** Hyprland exits immediately after login, or shows a black screen with cursor.

**Fix:**
1. Switch to TTY2: `Ctrl+Alt+F2`
2. Log in as thebeardbe
3. Check the Lua file for syntax errors:
   ```bash
   lua -e 'dofile("/home/thebeardbe/.config/hypr/hyprland.lua")'
   ```
4. Fix any errors reported
5. Restart Hyprland or rebuild

### Missing host.lua (not an error, handled gracefully)
**Symptom:** "Host file not found, using defaults" in Hyprland logs. This is normal on first deploy before host.lua is deployed.

**Fix:** Rebuild — the file will be deployed by home-manager.

### greetd configuration issue
**Symptom:** TTY login screen doesn't launch Hyprland.

**Check:**
```bash
systemctl status greetd
journalctl -u greetd -n 50
```

**Verify the command in `common/configuration.nix`:**
```nix
command = "... --cmd 'Hyprland -c /home/thebeardbe/.config/hypr/hyprland.lua'";
```

Make sure:
- `programs.hyprland.enable = true` (in common/configuration.nix)
- `wayland.windowManager.hyprland.enable = true` (in home/modules/hyprland.nix)
- The Lua file path exists and is readable

### NVIDIA GPU issues (theConstruct)
**Symptom:** Hyprland crashes or shows artifacts on NVIDIA hardware.

**Check in `hosts/theConstruct/system/gpu.nix`:**
```nix
hardware.graphics.enable = true;
services.xserver.videoDrivers = ["nvidia"];
hardware.nvidia.modesetting.enable = true;
boot.kernelParams = ["nvidia_drm.modeset=1"];
```

**Additional checks:**
```bash
# Verify NVIDIA driver loaded
lsmod | grep nvidia
nvidia-smi

# Check Hyprland logs for GPU errors
journalctl -u greetd -n 100 | grep -i nvidia
```

## Lua Config Issues

### Duplicate keybinds
**Symptom:** Keybind doesn't work, or second bind is silently ignored.

**Fix:** Search for duplicate key combos in `home/files/hyprland.lua`:
```bash
grep -n 'hl.bind' ~/.config/hypr/hyprland.lua | sort -t'"' -k2
```

### hyprshell keybinds not working
**Symptom:** Alt+Tab doesn't show window switcher.

**Check:**
1. Is `hyprshell` installed? → `which hyprshell`
2. Is it started in the autostart block?
   ```lua
   hl.exec_cmd("hyprshell run -c ~/.config/hyprshell/config.toml")
   ```
3. Is `hyprshell-config.toml` deployed and correct?
   ```bash
   cat ~/.config/hyprshell/config.toml
   ```
4. Does the config use the correct modifier/key? The TOML should show:
   ```toml
   [windows.switch]
   modifier = "alt"
   key = "Tab"
   ```

### exec_cmd targets not found
**Symptom:** Keybind does nothing, no error visible.

**Fix:** Verify the command exists:
```bash
which goto-workspace
which pick-wallpaper
which hyprlock
which hyprshot
which wlogout
```
These scripts are provided by `home/modules/hyprland.nix` as `writeShellScriptBin` packages and should be in PATH.

### Workspace wallpaper script not working
**Symptom:** Workspace switching doesn't set wallpaper.

**Check:**
1. `goto-workspace` script exists: `which goto-workspace`
2. Wallpapers directory exists: `ls ~/Pictures/Wallpapers/`
3. `hyprpaper` is running: `pgrep hyprpaper`
4. Cache file permissions: `ls -la ~/.cache/workspace-wallpapers`

## Waybar Issues

### Waybar not showing
**Symptom:** No status bar at top of screen.

**Check:**
```bash
systemctl --user status waybar
journalctl --user -u waybar -n 50
```

### Waybar modules missing
Common issues:
- **Backlight:** Only works on laptops (disabled on theConstruct desktop)
- **Battery:** Only works on laptops (disabled on theConstruct desktop)
- **Bluetooth:** Requires `blueman-applet` running for full functionality
- **PulseAudio:** Requires PulseAudio/PipeWire running
- **Custom/notification:** Requires `swaync` (SwayNotificationCenter) running
- **Custom/power:** Requires `wlogout` installed

### Waybar CSS not applying correctly
**Symptom:** Wrong colors or missing transparency.

**Check:** The `rgba()` values are computed from `theme.json` at build time. Changes to `theme.json` require a full rebuild:
```bash
sudo nixos-rebuild switch --flake .#$(hostname)
```

## hyprlock Issues

### Multiple hyprlock instances stacking
**Symptom:** Unlocking shows multiple lock screens layered on top of each other.

**Fix:** This is handled by the `lock_cmd` in `home/modules/hypridle.nix`:
```nix
lock_cmd = "pidof hyprlock || hyprlock";
```
If it still happens, kill all hyprlock processes:
```bash
pkill hyprlock
```

### hyprlock not starting from keybind
**Symptom:** Super+L does nothing.

**Check:**
```bash
which hyprlock
hyprlock --version
```
Verify the keybind in the Lua config:
```lua
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
```

## Theme Changes Not Applying

### After editing theme.json
Changes to `theme.json` affect multiple modules (Waybar, Kitty, Wofi, Hyprlock, Starship). A full rebuild is required:
```bash
sudo nixos-rebuild switch --flake .#$(hostname)
```

### Individual component not updating
- **Kitty:** May need to close and reopen kitty (or `kitty @ set-colors --all` for live reload)
- **Waybar:** Restart: `systemctl --user restart waybar`
- **Wofi:** No restart needed (reads config on each launch)
- **Hyprlock:** No restart needed (reads config on each invocation)
- **Starship:** Re-source shell config or open new terminal

## Nix Build Failures

### Hash mismatch
**Symptom:** `hash mismatch in file ...`

**Fix:** Update the hash in the package definition, or update flake.lock:
```bash
nix flake update
sudo nixos-rebuild switch --flake .#$(hostname)
```

### Infinite recursion / stack overflow
**Symptom:** `infinite recursion encountered`

**Fix:** Usually caused by circular imports. Check your import chains for loops.

### Undefined variable
**Symptom:** `undefined variable 'xxx'`

**Fix:** Check that the variable is in scope:
- `theme` is only available in home-manager modules (via `extraSpecialArgs`)
- `unstable` is available in both system and home-manager (via `specialArgs` and `extraSpecialArgs`)
- `inputs` is only available in system modules (via `specialArgs`), NOT in home-manager

### Package not found
**Symptom:** `attribute 'xxx' missing`

**Fix:**
1. Check nixpkgs for the package: `nix search nixpkgs <name>`
2. It might be in `unstable` channel → use `unstable.<pkgname>`
3. It might need `config.allowUnfree = true`
4. The attribute path might be nested (e.g., `pkgs.gnome.gnome-tweaks` not `pkgs.gnome-tweaks`)

### Rebuild takes too long
Tips:
- Use `dry-build` first to catch eval errors quickly
- Check that you're not downloading huge unfree packages accidentally
- Consider using `nixos-rebuild test` instead of `switch` for testing (rolls back on reboot)

## Hyprland Ecosystem Component Issues

### hyprpaper
```bash
# Check if running
pgrep hyprpaper
# Check wallpapers
hyprctl hyprpaper listloaded
# Set wallpaper
hyprctl hyprpaper wallpaper ",/path/to/wallpaper.png"
```

### hyprshot (screenshots)
**Symptom:** Screenshots not working.

**Check:**
```bash
which hyprshot
# Common flags:
hyprshot -m output    # Full screen
hyprshot -m window    # Active window
hyprshot -m region    # Select region
```

### hypridle (sleep/lock)
```bash
# Check status
systemctl --user status hypridle
# Check listeners
hyprctl notify -1 1000 "rgb(ff0000)" "test"  # Send test notification
```

### wlogout (power menu)
**Symptom:** Power menu not showing.

**Check:**
```bash
which wlogout
# Test from terminal:
wlogout
```

## Network/Connectivity

### NetworkManager not connecting
```bash
systemctl status NetworkManager
nmcli device status
```

### Tailscale issues
```bash
systemctl status tailscaled
tailscale status
# Our config disables route acceptance: --accept-routes=false
```

### Bluetooth not working
```bash
systemctl status bluetooth
bluetoothctl power on
bluetoothctl devices
```

## Git/Files

### home.file deployment not working
**Symptom:** Edited a source file but the deployed file didn't change.

**Fix:** Rebuild. Home-manager only updates files during `nixos-rebuild switch`:
```bash
sudo nixos-rebuild switch --flake .#$(hostname)
```
Then check: `ls -la ~/.config/hypr/hyprland.lua` — it should be a symlink into /nix/store.

Note: home-manager deployed files are **read-only symlinks** into the Nix store. Edit the **source files** in `~/nixos-config/`, not the deployed symlinks directly.

### Hand-editing deployed files
Even though home-manager files are read-only symlinks, you can temporarily fix a broken config:
1. Remove the symlink: `rm ~/.config/hypr/hyprland.lua`
2. Create a writable copy: `cp ~/nixos-config/home/files/hyprland.lua ~/.config/hypr/hyprland.lua`
3. Edit and test
4. Rebuild to restore normal home-manager management

### Nix flake check warnings about configType
The home-manager hyprland module at version 2026-04-24 only generates hyprlang configs (`hyprland.conf`). It does not support native Lua file generation. Since we deploy our own Lua config via `home.file`, we don't enable the home-manager hyprland module at all. Systemd activation is handled in the Lua autostart block, and the system-level `programs.hyprland.enable` handles Hyprland availability and portals.
