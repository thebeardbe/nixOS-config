# Renaissance Man Unified Config — Full Repository Guide

> **Repo root:** `/home/thebeardbe/nixos-config` (or `~/nixos-config`)
> **Current:** Built for `theConstruct` (desktop), also manages `foxyNix` (laptop)
> **Theme:** Otherland network (cyberpunk/VR-simulation aesthetic)
> **Hyprland config format:** Lua (`hl.*` API) — `home/files/hyprland.lua`
> **Last build:** 2026-06-30

---

## 1. Architecture Overview

```
flake.nix                    # Entry point — exports nixosConfigurations for all hosts
theme.json                   # Central design tokens — shared by ALL modules
├── common/                  # Shared system-level config
│   ├── configuration.nix    # Everything common to both machines
│   └── modules/             # Reusable system modules (touchpad, security, etc.)
├── home/                    # Shared home-manager config (user-level)
│   ├── home.nix             # Entry point for user config
│   ├── packages.nix         # Shared user packages (apps, fonts, tools)
│   ├── files/               # Static dotfiles (screenrc, agent settings, Lua config)
│   └── modules/             # Reusable home-manager modules
├── hosts/
│   ├── theConstruct/        # Desktop: AMD Ryzen 5600 + RTX 3060 Ti
│   │   ├── default.nix      # Host entry — imports hardware + system + common
│   │   ├── hardware-configuration.nix  # Auto-generated
│   │   ├── system/          # System-level overrides
│   │   │   ├── default.nix  # Hostname, bootloader, drives
│   │   │   ├── gpu.nix      # NVIDIA config
│   │   │   └── steam.nix    # Steam + remote play
│   │   └── home/            # User-level overrides
│   │       ├── default.nix  # Font overrides, waybar, host.lua deployment
│   │       ├── hypr-host.lua # Dual monitor layout
│   │       └── packages.nix # steam-run, mangohud, prismlauncher
│   └── foxyNix/             # Laptop: Intel
│       ├── default.nix
│       ├── hardware-configuration.nix
│       ├── system/          # Touchpad, silent boot, Ubuntu dual-boot
│       └── home/
│           ├── default.nix  # host.lua deployment
│           ├── hypr-host.lua # Touchpad settings
│           └── packages.nix # (empty — ready for laptop-specific packages)
├── secrets/                 # Docs for the private nix-secrets flake
├── wallpapers/              # 6 Otherland-themed wallpapers
├── antigravity-fhs.nix      # FHS environment for Playwright (Electron testing)
├── theme.json               # Central colors, fonts, opacity, spacing
├── flake.lock               # Locked Nixpkgs revisions
├── README.md                # Quick-start README
└── REPO-MAP.md              # ← This file
```

---

## 2. flake.nix — Entry Point

**File:** `flake.nix`

### Inputs
| Input | URL | Purpose |
|---|---|---|
| `nixpkgs` | `nixos/nixpkgs/nixos-unstable` | Main package set |
| `home-manager` | `nix-community/home-manager` | User config management |
| `nixpkgs-unstable` | `nixos/nixpkgs/nixpkgs-unstable` | Bleeding-edge pkgs (signal-desktop) |
| `nix-secrets` (optional/disabled) | Private git repo | Secret values (auth.json for pi agent) |

### Outputs
- `nixosConfigurations.foxyNix` — Laptop config
- `nixosConfigurations.theConstruct` — Desktop config

### Key Mechanics
- Reads `theme.json` and passes it as `specialArgs` to **home-manager** modules (via `extraSpecialArgs`).
- `unstable` is an imported instance of `nixpkgs-unstable` available to all modules.
- `mkHost` is a helper that assembles a full NixOS config for each host:
  1. Host's own `default.nix`
  2. Home-manager with shared `home/home.nix` + host-specific `home/default.nix`
  3. Optional private secret modules (toggle by uncommenting the `nix-secrets` input)
- No package overlays (hyprshell uses stock nixpkgs — the Lua config makes its IPC work natively)

### Build commands (run from ~/nixos-config)
```bash
# Rebuild current machine
sudo nixos-rebuild switch --flake .#$(hostname)

# Build specific machine
sudo nixos-rebuild switch --flake .#theConstruct
sudo nixos-rebuild switch --flake .#foxyNix
```

---

## 3. theme.json — Central Design System

**File:** `theme.json`

This is THE place to tweak the visual identity. Changes here flow into:
- Waybar (background, border, accent, critical colors)
- Kitty (font family, size, opacity)
- Wofi (accent, text, border colors)
- Hyprlock (background, text, accent, font)
- Starship (hostname, directory, character colors)
- Hyprland (border colors are set in Lua — `home/files/hyprland.lua`)

```json
{
  "colors": {
    "background": "#000b1e",     // Deep navy blue — main bg
    "text": "#c0c0c0",           // Silver gray — main text
    "accent": "#0abdc6",         // Cyan/teal — interactive elements
    "critical": "#ff4500",       // Orange-red — destructive/urgent
    "border": "#0abdc6"          // Same as accent — borders
  },
  "spacing": {
    "gaps_in": 5,                // Inner gaps between windows
    "gaps_out": 10,              // Outer gaps around workspaces
    "border_width": 2,           // Window border width
    "radius": 10                 // Corner rounding
  },
  "font": {
    "family": "FiraCode Nerd Font",
    "size": 11
  },
  "opacity": 0.92               // Waybar background opacity
}
```

**To change**: edit `theme.json`, then `sudo nixos-rebuild switch --flake .#$(hostname)`.

---

## 4. Common System Config (`common/configuration.nix`)

**File:** `common/configuration.nix`

Shared across both machines. Imports all modules from `common/modules/`.

### What it sets up
| Category | Details |
|---|---|
| **Display Manager** | `greetd` + `tuigreet` (TTY greeter) → launches **`Hyprland -c ~/.config/hypr/hyprland.lua`** |
| **Window Manager** | Hyprland enabled system-wide (`programs.hyprland`) |
| **Networking** | NetworkManager, Tailscale (`--accept-routes=false`), `resolved` DNS |
| **Time/Locale** | `Europe/Brussels`, `en_US.UTF-8`, US keyboard with `altgr-intl` |
| **Power** | thermald (Intel), fstrim (SSD trim), 8GB swapfile |
| **Nix GC** | Daily auto-GC + weekly tiered profile cleanup (keep all ≤7d, 1/week ≤30d, 1/month ≤180d) |
| **Docker** | Enabled |
| **Flatpak** | Enabled |
| **SSH** | OpenSSH server enabled |
| **Printing** | CUPS + gutenprint + sane-airscan + Avahi (bonjour discovery) |
| **Bluetooth** | Enabled, auto-power-on, Blueman tray + overskride |
| **Security** | PAM hyprlock, gnome-keyring login, polkit |
| **Users** | `thebeardbe` user with groups: networkmanager, wheel, video, audio, input, docker, lp, scanner. Shell: zsh |
| **Env vars** | `WLR_NO_HARDWARE_CURSORS=1`, `NIXOS_OZONE_WL=1` |
| **Graphical** | GVfs enabled (for Yazi SFTP), GPU acceleration, xwayland |
| **Packages** | vim, wget, git, curl, htop, pulseaudio (pactl CLI), pavucontrol (audio profile GUI) |

### Common Modules (`common/modules/`)

**`touchpad.nix`** — Optional touchpad config (toggle per-host):
```nix
mySystem.touchpad.enable = true;  # Enable in host's system/default.nix
```
**NOTE:** With Lua Hyprland, touchpad is also configured in `hosts/foxyNix/home/hypr-host.lua` via `hl.config({ input = { touchpad = { ... } } })`. The `services.libinput` toggle is for X11 compatibility.

**`security.nix`** — PAM service for hyprlock, gnome-keyring integration on login, PolicyKit for GUI privilege elevation.

**`hardware.nix`** — Printing (CUPS + gutenprint), scanning (SANE + airscan), network discovery (Avahi/Bonjour), printer management tools.

**`bluetooth.nix`** — Bluetooth hardware + power-on-boot + Blueman tray + overskride + bluez tools.

**`users.nix`** — Defines the `thebeardbe` user with all group memberships.

---

## 5. Common Home Config (`home/`)

### `home/home.nix` — Entry Point

Imports all home modules and sets:
- `home.username = "thebeardbe"`
- `home.homeDirectory = "/home/thebeardbe"`
- SSH config (auto-add keys, GitHub uses `~/.ssh/github`)
- Git config (user name/email)
- Bash aliases (`ll`, `conf`, `rebuild`)
- Dconf dark mode for GTK4/libadwaita apps
- Deploys dotfiles: `~/.screenrc`, `~/.config/hyprshell/config.toml`, `~/.config/hypr/hyprland.lua`

### `home/packages.nix` — Shared User Packages

| Category | Packages |
|---|---|
| **Communication** | obsidian, discord, signal-desktop (unstable), firefox, enpass, gemini-cli |
| **Fonts** | FiraCode, JetBrains Mono, Meslo LG (Nerd Fonts) |
| **System Tools** | networkmanagerapplet, pavucontrol, pamixer, fastfetch, nwg-look, tree, btop, eza, bat, brightnessctl |
| **Hyprland Ecosystem** | hyprlock, hypridle, hyprshot, wofi, kitty, hyprpaper, wlogout, **hyprshell** |
| **Utilities** | fzf, screen, libnotify, swaynotificationcenter |
| **Yazi Deps** | ffmpegthumbnailer, jq, poppler, fd, ripgrep |
| **Playwright** | playwright-driver.browsers, glib, expat, libxshmfence, libGL |
| **Other** | sshfs |

### Home Modules (`home/modules/`)

#### `appearance.nix` — GTK/Qt/Kitty/Wofi Theming
- **GTK**: Adwaita-dark theme, Papirus-Dark icons
- **Qt**: Forces GTK3 platform theme + adwaita-dark style
- **Cursor**: Bibata-Modern-Classic (24px)
- **Kitty**: Cyberpunk-Neon theme, font from `theme.json`, opacity from `theme.json`
- **Wofi**: Custom CSS using `theme.json` colors

#### `hyprland.nix` — Window Manager (package + scripts only)

**No longer contains hyprlang settings.** The Hyprland configuration is now entirely in `home/files/hyprland.lua` (Lua format).

This module now only handles:
- Enabling Hyprland via home-manager (for systemd integration)
- Deploying the `goto-workspace` and `pick-wallpaper` scripts
- Deploying the `hyprpaper.conf`

#### `home/files/hyprland.lua` — The Main Hyprland Config (Lua)

**File:** `home/files/hyprland.lua`

Complete Hyprland configuration using the native Lua `hl.*` API. This replaces the old hyprlang settings in `home/modules/hyprland.nix`.

**Structure:**
| Section | API | Details |
|---|---|---|
| Monitor | `hl.monitor({...})` | Default auto-detect; overridden by host's `hypr-host.lua` |
| Autostart | `hl.on("hyprland.start", ...)` | Systemd activation, nm-applet, blueman, hyprpaper, hyprshell, wallpaper |
| Env vars | `hl.env(...)` | PLAYWRIGHT_BROWSERS_PATH, HOME, cursor |
| Look & feel | `hl.config({ general, decoration, misc })` | Gaps, borders, rounding, opacity, blur, shadow |
| Input | `hl.config({ input })` | Keyboard layout `us+altgr-intl` |
| Animations | `hl.curve()`, `hl.animation()` | Custom bezier, default animations |
| Keybinds | `hl.bind(...)` | See keybinds table below |
| Window rules | `hl.window_rule(...)` | Fix XWayland drag issues |
| Layer rules | `hl.layer_rule(...)` | No-anim for hyprshell overlays |

**Host overrides:** Each host's `home/hypr-host.lua` is loaded via `dofile()` in the main config. It can set monitors, workspace rules, touchpad, etc.

**Keybinds:**
| Shortcut | Action |
|---|---|
| `Super + Q` | Open kitty terminal |
| `Super + C` | Close focused window |
| `Super + M` | Exit Hyprland |
| `Super + E` | Open Yazi (in kitty) |
| `Super + V` | Toggle floating |
| `Super + Space` | Wofi app launcher |
| `Super + P` | Toggle pseudo-tiling |
| `Super + J` | Toggle split direction |
| `Super + F` | Fullscreen |
| `Alt + Tab` | **hyprshell window switcher** (thumbnails, all workspaces) |
| `Alt + Shift + Tab` | hyprshell switcher (reversed) |
| `Alt + Grave` | hyprshell switcher (reversed) |
| `Super + L` | Lock screen (`hyprlock` — hypridle handles idle DPMS) |
| `Super + Shift + W` | Pick wallpaper (wofi picker) |
| `Super + Shift + R` | Reload Hyprland config |
| `Print` | Screenshot full output |
| `Super + Print` | Screenshot active window |
| `Super + Shift + P` | Screenshot selected region |
| `Super + Ctrl + P` | Screenshot active window |
| `Super + Alt + P` | Screenshot full screen |
| `XF86AudioRaiseVolume` / `LowerVolume` / `Mute` | Volume control (repeating) |
| `XF86MonBrightnessUp` / `Down` | Brightness control (repeating) |
| `XF86PowerOff` | Power menu (wlogout) |
| `Super + 1-10` | Switch to workspace (sets random per-workspace wallpaper) |
| `Super + Shift + 1-10` | Move window to workspace |

**Release binds (registered by hyprshell via IPC):**
- `Alt_L/R` release → closes switcher, focuses selected window
- `Shift_L/R` release → closes switcher

**Autostart:** Systemd session activation → nm-applet → blueman-applet → hyprpaper → hyprshell run → goto-workspace 1

**Custom Scripts:**
- `goto-workspace` — Changes workspace AND sets a random per-workspace wallpaper (cached in `~/.cache/workspace-wallpapers`)
- `pick-wallpaper` — Wofi-based wallpaper picker, shows cleaned-up names (strips "otherland-" prefix), saves per-workspace
- (no dedicated lock script — `loginctl lock-session` + hypridle `lock_cmd` handles everything)

#### `waybar.nix` — Status Bar

Top bar with modules:
- **Left**: Workspaces (with Unicode/icon window names) + mode indicator
- **Center**: Active window title + clock (24h format)
- **Right**: Backlight, PulseAudio, Bluetooth, CPU, Memory, Battery, System tray, Notification center, Power button

Uses `theme.json` colors computed to RGB for Waybar CSS transparency.

#### `starship.nix` — Shell Prompt + Zsh Config
- Starship prompt with: user@host → directory → git branch → git status → time → character
- Zsh with completion, autosuggestions, syntax highlighting
- Aliases: `rebuild` (git add + nixos-rebuild), `v` (nvim), `conf` (open config), `ls` (eza), `cat` (bat)
- Ctrl+Left/Right word jump in zsh

#### `hyprlock.nix` — Lockscreen
Otherland-themed lock screen:
- "OTHERLAND: $TIME" in large font
- "SIMULATION LEVEL: STABLE" subtitle
- Blurred screenshot background
- Input field says "simulation access code required"
- All colors from `theme.json`

#### `hypridle.nix` — Auto-Sleep System
- `lock_cmd` = `pidof hyprlock || hyprlock` — runs when D-Bus lock event received
- 5 min inactivity → `loginctl lock-session` → D-Bus lock → `lock_cmd` runs hyprlock
- 5.5 min (330s) → DPMS off via dispatch
- user input → `on-resume` re-enables DPMS
- Manual `Super+L` → `loginctl lock-session` → same path as idle (hyprlock runs, DPMS works)
- Before suspend → `loginctl lock-session`, after resume → DPMS on

#### `neovim.nix` — Text Editor
- Neovim with vi/vim aliases
- LSP packages: `lua-language-server`, `nil` (Nix LS)
- Clipboard: `xclip`

#### `yazi.nix` — Terminal File Manager
- Hidden files shown by default
- Custom keybinds: `M` to mount SFTP via `gio mount`, `g v` to go to GVfs mounts
- `y` shell wrapper alias
- Preview support for videos (ffmpegthumbnailer), JSON (jq), PDFs (poppler)

#### `agent.nix` — Pi Coding Agent (SDK Integration)
- Node.js + npm
- `~/.npm-global/bin` in PATH, npm prefix set to `~/.npm-global`
- Settings from `home/files/agent/settings.json` (provider: deepseek, model: deepseek-v4-flash, thinking: high)
- Auth.json deployed from private secrets on first install

#### `secrets.nix` — Secret Option Declarations
Declares `mySecrets.piAuth` option (nullable string). Values provided by the optional `nix-secrets` flake input.

#### `hyprshell-config.toml` — Hyprshell Window Switcher Config

**File:** `home/files/hyprshell-config.toml` → `~/.config/hyprshell/config.toml`

Controls hyprshell's window switcher behavior:
```toml
[windows.switch]
modifier = "alt"
key = "Tab"
filter_by = []           # Show ALL windows across workspaces/monitors
switch_workspaces = true # Auto-switch to the selected window's workspace
kill_key = "q"           # Press Q while holding Alt to kill the selected window

[windows.overview]
modifier = "super"
key = "Super_L"
# Also configures the app launcher (width, max_items, default_terminal)
```

**Important:** hyprshell's window switcher and overview register their own keybinds via Hyprland IPC (`eval hl.bind(...)` in Lua). These work natively because the active Hyprland config is Lua.

---

## 6. Host: theConstruct (Desktop)

**Hardware:** AMD Ryzen 5600 + NVIDIA RTX 3060 Ti
**Role:** Gaming / workstation

### System (`hosts/theConstruct/system/`)

**`default.nix`:**
- Hostname: `theConstruct`
- Bootloader: GRUB with EFI support + OS prober (Windows dual-boot)
- exfat filesystem support
- 4 auto-mounted exfat drives:
  - `/mnt/golden-city` (B89B-399D)
  - `/mnt/blue-fire` (8CB1-7A97)
  - `/mnt/black-glass` (32CA-F4E4)
  - `/mnt/silver-light` (BAE0-0704)

**`gpu.nix`:** NVIDIA config
- `nvidia` video driver (proprietary, not open)
- Modesetting enabled
- `nvidia_drm.modeset=1` kernel param
- 32-bit graphics enabled (for Steam/Proton)
- Stable driver package
- `nvidia-vaapi-driver` for hardware video decode in Steam/Chromium

**`steam.nix`:** Steam with remote play + dedicated server firewall ports open
- **Sunshine** game streaming host enabled (`capSysAdmin` for Wayland/KMS capture, firewall open)
- Moonlight client on foxyNix connects here

### Home (`hosts/theConstruct/home/`)

**`default.nix`:**
- Forces smaller GTK font (10px) for ultrawide
- Forces smaller kitty font (9px)
- Removes backlight and bluetooth from Waybar (desktop has no battery/backlight)
- Deploys `hypr-host.lua`

**`hypr-host.lua`:**
```lua
-- Dual monitor setup
hl.monitor({ output = "DP-2", mode = "1920x1080@165", position = "0x0",    scale = "1" })
hl.monitor({ output = "DP-1", mode = "3440x1440@60",  position = "-760x-1440", scale = "1" })
-- Workspaces 1-7 → DP-2 (gaming), 8-10 → DP-1 (ultrawide)
```

**`packages.nix`:** steam-run, mangohud, prismlauncher (Minecraft)

---

## 7. Host: foxyNix (Laptop)

**Hardware:** Intel laptop
**Role:** Daily driver

### System (`hosts/foxyNix/system/`)

**`default.nix`:**
- Hostname: `foxyNix`
- Touchpad enabled (`mySystem.touchpad.enable = true`) — X11 libinput fallback
- Bootloader: systemd-boot with Ubuntu dual-boot entry
- Silent boot: plymouth, quiet splash, reduced log levels
- Latest Linux kernel (`linuxPackages_latest`)

### Home (`hosts/foxyNix/home/`)

**`default.nix`:**
- Deploys `hypr-host.lua`

**`hypr-host.lua`:**
```lua
-- Touchpad settings (Hyprland-native, replaces services.libinput)
hl.config({
    input = {
        touchpad = {
            natural_scroll = true,
            click_method   = "clickfinger",
            tap            = true,
        },
    },
})
```

**`packages.nix`:** `moonlight-qt` — game streaming client (connects to Sunshine on theConstruct)

---

## 8. Additional Files

### `antigravity-fhs.nix`
FHS environment for running `antigravity` (a Playwright/Electron app that needs browser libraries). Provides all the `.so` files Chromium/Electron need under a clean FHS chroot.

### `home/files/agent/settings.json`
Pi coding agent default settings:
```json
{
  "defaultProvider": "deepseek",
  "defaultModel": "deepseek-v4-flash",
  "defaultThinkingLevel": "high",
  "theme": "dark",
  "hideThinkingBlock": false
}
```

### `home/files/screenrc`
GNU Screen config with vim-style tab navigation (Ctrl+A + h/j/k/l) and 4 initial tabs.

### `secrets/README.md`
Documents how to set up the private `nix-secrets` flake:
- Expected structure: `common/shared.nix` + `hosts/{hostname}/agent.nix`
- Each module sets `mySecrets.piAuth` via `builtins.readFile ./auth.json`
- Currently disabled in flake.nix (commented out) — uncomment to use

### `wallpapers/`
6 Otherland-themed wallpapers + `solid-bg.png` (a tiny solid color fallback):
- `otherland-ascii.png`
- `otherland-blackhole.png`
- `otherland-geometric-blue.png` (default)
- `otherland-traces-purple.png`
- `otherland-tron-purple.png`
- `solid-bg.png`

Wallpapers are expected to live at `~/Pictures/Wallpapers/` on the live system (symlinked or copied).

---

## 9. How to Modify Common Things

| What to Change | File(s) |
|---|---|
| Colors / fonts / opacity | `theme.json` |
| Add a system package | `common/configuration.nix` → `environment.systemPackages` |
| Add a user package | `home/packages.nix` |
| Add a Hyprland keybind | `home/files/hyprland.lua` → `hl.bind(...)` section |
| Change Hyprland appearance (gaps, blur, etc.) | `home/files/hyprland.lua` → `hl.config({ general, decoration })` |
| Change Waybar layout | `home/modules/waybar.nix` → `settings.mainBar` |
| Change wallpaper | `home/files/hyprland.lua` → `hl.on("hyprland.start")` + `hyprpaper.conf` |
| Add a new machine | Create `hosts/<name>/`, add to `flake.nix` `nixosConfigurations` |
| Change lock screen text | `home/modules/hyprlock.nix` |
| Add GTK theme | `home/modules/appearance.nix` → `gtk.theme` |
| Change shell prompt | `home/modules/starship.nix` |
| Enable secrets | Uncomment `nix-secrets` in `flake.nix`, create private flake |
| Adjust Nix GC strategy | `common/configuration.nix` → `systemd.services.nix-gc-tiered` |
| Change keyboard layout | `home/files/hyprland.lua` → `hl.config({ input = { kb_layout, kb_variant } })` |
| Toggle touchpad | `common/modules/touchpad.nix` for X11, or host's `hypr-host.lua` for Hyprland |
| Add a new wallpaper | Drop in `wallpapers/`, copy to `~/Pictures/Wallpapers/`, pick via `Super+Shift+W` |
| Change monitor layout | Host's `hypr-host.lua` → `hl.monitor({...})` |
| Change hyprshell behavior | `home/files/hyprshell-config.toml` |
| Change bootloader | Host's `system/default.nix` → `boot.loader` |

---

## 10. Rebuild Flow

```
1. Edit file(s) in ~/nixos-config/
2. (Optional) git add + git commit
3. sudo nixos-rebuild switch --flake .#$(hostname)
4. On foxyNix, the Zsh alias is: rebuild
   (which does: pushd ~/nixos-config && git add . && sudo nixos-rebuild switch --flake .#$(hostname) && popd)
```

---

## 11. Config Format: Lua vs hyprlang

The Hyprland config is written in **Lua** (`home/files/hyprland.lua`) using the native `hl.*` API. This is the format that Hyprland 0.55.x uses natively — passing configs via `eval hl.dispatch(...)` requires the Lua config manager to be active.

### Why Lua instead of hyprlang?

1. **hyprshell compatibility** — hyprshell 4.x uses `eval hl.dispatch(...)` internally for window/workspace switching. This only works when Hyprland's Lua config manager is active.
2. **hyprshell IPC** — hyprshell registers its own keybinds (Alt+Tab, Alt release, etc.) via `eval hl.bind(...)` at runtime. No manual socat commands needed.
3. **Future-proof** — Hyprland is moving toward Lua as the primary config format.

### How it works

1. `greetd` launches `Hyprland -c ~/.config/hypr/hyprland.lua` (set in `common/configuration.nix`)
2. The Lua config loads and calls `hl.monitor()`, `hl.config()`, `hl.bind()`, etc.
3. At the top of the main Lua file, it does `dofile("~/.config/hypr/host.lua")` to load host-specific overrides
4. hyprshell starts via `hl.on("hyprland.start", ...)` and registers its own keybinds via IPC
5. When you press Alt+Tab, hyprshell shows the switcher — selecting a window calls `hl.dsp.focus()` via IPC → works because Lua config is active

---

## 12. Keybinds: hyprshell Window Switcher

The Alt+Tab window switcher is provided by **hyprshell 4.10.7** (GTK4, nixpkgs package):
- Shows **thumbnails** of ALL windows across ALL workspaces
- Cycles with Tab/Shift+Tab while holding Alt
- **Auto-switches to the selected window's workspace** on Alt release
- Press **Q** while holding Alt to kill the selected window
- Also works as an **overview/launcher** with the Super key

**Keybinds registered by hyprshell itself (via IPC):**
| Key | Action |
|---|---|
| `Alt + Tab` | Open window switcher (forward) |
| `Alt + Shift + Tab` | Open window switcher (reversed) |
| `Alt + Grave` | Open window switcher (reversed) |
| `Alt` release | Close switcher, focus selected window |
| `Shift` release | Close switcher |

---

## 13. Quick Reference

| Command | What it does |
|---|---|
| `sudo nixos-rebuild switch --flake .#theConstruct` | Build and switch to new generation |
| `sudo nixos-rebuild test --flake .#theConstruct` | Test without making permanent |
| `sudo nixos-rebuild boot --flake .#theConstruct` | Build for next boot only |
| `sudo nix-collect-garbage -d` | Clean up old store paths |
| `nix-env --list-generations -p /nix/var/nix/profiles/system` | List boot entries |
| `sudo nix-env --delete-generations -p /nix/var/nix/profiles/system <N>` | Remove specific generation |
| `hyprctl reload` | Reload Hyprland config (no reboot needed) |
| `hyprctl hyprpaper wallpaper ,<path>` | Change wallpaper on the fly |
| `Super + Shift + W` | Interactive wallpaper picker |
| `Super + Space` | Wofi app launcher |
| `Super + L` | Lock screen (`hyprlock`) |
| `Super + Shift + R` | Reload Hyprland |
| `Alt + Tab` | hyprshell window switcher (thumbnails) |
| `Alt + Grave` | hyprshell switcher (reversed) |
| `nm-applet` | NetworkManager tray |
| `blueman-applet` | Bluetooth tray |
| `hyprshot -m output` | Screenshot full screen |
| `hyprshot -m window` | Screenshot active window |
| `hyprshot -m region` | Screenshot selected area |
| `Super + Shift + P` | Screenshot selected region |
| `Super + Ctrl + P` | Screenshot active window |
| `Super + Alt + P` | Screenshot full screen |
| `wlogout` | Power menu |
| `btop` | Resource monitor (click battery in Waybar) |
| `pavucontrol` | Audio profile GUI (click volume in Waybar) |
| `pactl list cards` | List audio devices for profile switching |
| `overskride` | Bluetooth manager (click Bluetooth in Waybar) |
| `swaync-client -op` | Open notification center (click bell in Waybar) |

---

## 14. Result Symlink

The `result` symlink at the repo root points to the last built NixOS system derivation:
```
result -> /nix/store/...-nixos-system-<hostname>-<version>
```
This is created when running `nixos-rebuild` and can be used to inspect the built config.
