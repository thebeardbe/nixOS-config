# Renaissance Man Unified Config — Full Repository Guide

> **Repo root:** the `nixOS-config` checkout in `$HOME` (`~/nixOS-config` on theConstruct, `~/nixos-config` on foxyNix)
> **Current:** Built for `theConstruct` (desktop), also manages `foxyNix` (laptop)
> **Theme:** Otherland network (cyberpunk/VR-simulation aesthetic)
> **Hyprland config format:** Lua (`hl.*` API) — `home/files/hyprland.lua`
> **Last build:** 2026-08-29

---

## 1. Architecture Overview

```
flake.nix                    # Entry point — exports nixosConfigurations for all hosts
theme.json                   # Central design tokens — shared by ALL modules
├── .pi/skills/nixos-hyprland/  # Pi agent skill: Lua API ref, troubleshooting, patterns
├── common/                  # Shared system-level config
│   ├── configuration.nix    # Shared config hub — imports every common/modules/* module
│   └── modules/             # Reusable system modules (19 modules)
├── home/                    # Shared home-manager config (user-level)
│   ├── home.nix             # Entry point
│   ├── packages.nix         # Shared user packages
│   ├── files/               # Dotfiles (hyprland.lua, screenrc, llama compose)
│   └── modules/             # Home-manager modules (15 modules + hyprpaper.conf)
├── hosts/
│   ├── theConstruct/        # Desktop: AMD Ryzen 5600 + RTX 3060 Ti
│   │   ├── default.nix      # Host entry
│   │   ├── hardware-configuration.nix
│   │   ├── system/          # Hostname, GRUB, NVIDIA, Steam, drives
│   │   └── home/            # Fonts, waybar, host.lua, gaming packages
│   └── foxyNix/             # Laptop: Intel
│       ├── default.nix
│       ├── hardware-configuration.nix
│       ├── system/          # Touchpad, silent boot, Ubuntu dual-boot
│       └── home/            # host.lua, packages (moonlight-qt)
├── secrets/                 # Docs for private nix-secrets flake
├── wallpapers/              # 6 Otherland-themed wallpapers
├── recovery-scripts/        # Standalone recovery tools (unlock-session)
├── theme.json               # Central colors, fonts, opacity, spacing
├── flake.lock
├── README.md
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
| `nixpkgs-unstable` | `nixos/nixpkgs/nixpkgs-unstable` | Bleeding-edge pkgs (signal-desktop, moonlight-qt) |
| `nix-secrets` (optional/disabled) | Private git repo | Secret values (auth.json for pi agent) |
| `proton` | `github:roman-16/proton-cli/v5.0.1` | Proton CLI (Mail/Drive/Calendar/Contacts), pinned to a tag |

### Outputs
- `nixosConfigurations.foxyNix` — Laptop config
- `nixosConfigurations.theConstruct` — Desktop config

### Key Mechanics
- Reads `theme.json` and passes it as `specialArgs` to **home-manager** modules (via `extraSpecialArgs`).
- `unstable` is an imported instance of `nixpkgs-unstable` available to all modules.
- `protonCli` is the upstream proton-cli package (flake input `proton`), handed to home modules via `extraSpecialArgs`.
- `mkHost` is a helper that assembles a full NixOS config for each host:
  1. Host's own `default.nix`
  2. Home-manager with shared `home/home.nix` + host-specific `home/default.nix`
  3. Optional private secret modules (toggle by uncommenting the `nix-secrets` input)
- No package overlays except one: `overlays/waybar-lua.nix` pins Waybar from
  git master, because 0.15.0 cannot dispatch workspace clicks under a Lua
  Hyprland config. Version-gated, see `NOTES.md`.

### Build commands (run from the repo checkout)
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
| **Power** | fstrim (SSD trim), 8GB swapfile. thermald (Intel) is host-specific: enabled on foxyNix only. |
| **Audio** | PipeWire with rtkit, 32-bit ALSA for Proton, low-latency config |
| **Nix GC** | Daily auto-GC + weekly tiered profile cleanup (keep all ≤7d, 1/week ≤30d, 1/month ≤180d) |
| **Auto-update** | Weekly `nix-flake-update` timer (Mon ~04:00 ± 2h) on **theConstruct only** (`mySystem.flakeUpdate.enable`): `nix flake update`, commit `flake.lock`, build — then either switch (ordinary update) or stage as the boot default and notify (kernel/NVIDIA change). foxyNix pulls and rebuilds manually. |
| **Docker** | Enabled |
| **Flatpak** | Enabled |
| **SSH** | OpenSSH server enabled |
| **Printing** | CUPS + gutenprint + sane-airscan + Avahi (bonjour discovery) |
| **Bluetooth** | Enabled, auto-power-on, Blueman tray + overskride |
| **Security** | PAM hyprlock, gnome-keyring login, polkit |
| **Users** | `thebeardbe` user with groups: networkmanager, wheel, video, audio, input, docker, lp, scanner, dialout (serial flashing). Shell: zsh |
| **Env vars** | `WLR_NO_HARDWARE_CURSORS=1`, `NIXOS_OZONE_WL=1` |
| **Graphical** | GVfs enabled (for Yazi SFTP), GPU acceleration, xwayland |
| **Portals** | GNOME portal for `Background` (Packet tray), hyprland portal for ScreenCast/Screenshot/GlobalShortcuts/RemoteDesktop; GNOME portal auto-restarts on crash (drop-in override) |
| **Packages** | vim, wget, git, curl, htop, pulseaudio (pactl CLI), pavucontrol (audio profile GUI), unlock-session (from recovery-scripts/) |

### Common Modules (`common/modules/`, 19 files)

**`touchpad.nix`** — Optional touchpad config (toggle per-host):
```nix
mySystem.touchpad.enable = true;  # Enable in host's system/default.nix
```
**NOTE:** With Lua Hyprland, touchpad is also configured in `hosts/foxyNix/home/hypr-host.lua` via `hl.config({ input = { touchpad = { ... } } })`. The `services.libinput` toggle is for X11 compatibility.

**`security.nix`** — PAM service for hyprlock, gnome-keyring integration on login, PolicyKit for GUI privilege elevation.

**`hardware.nix`** — Printing (CUPS + gutenprint), scanning (SANE + airscan), network discovery (Avahi/Bonjour), printer management tools.

**`bluetooth.nix`** — Bluetooth hardware + power-on-boot + Blueman tray + overskride + bluez tools.

**`users.nix`** — Defines the `thebeardbe` user with all group memberships.

**`audio.nix`** — PipeWire (32-bit ALSA for Proton/Wine) + rtkit real-time audio priority.

**`networking.nix`** — NetworkManager, Tailscale (`--accept-routes=false`), `resolved` DNS, OpenSSH server.

**`locale.nix`** — Time zone (`Europe/Brussels`), `en_US.UTF-8`, X11 `us`/`altgr-intl` keymap, console `us-acentos` keymap.

**`nix.nix`** — Unfree packages allowed, flakes + `nix-command`, store auto-optimise.

**`nix-gc.nix`** — Daily `nix.gc` + weekly tiered profile-generation cleanup (keep all ≤7d, 1/week ≤30d, 1/month ≤180d).

**`flake-update.nix`** — Declares `mySystem.flakeUpdate.enable`; weekly `nix-flake-update` service + timer (Mon ~04:00 ± 2h), enabled on exactly one host. The service never applies a kernel or NVIDIA driver change: it compares the built system's kernel and `libnvidia-ml` against `/run/booted-system` and, if either differs, runs `nixos-rebuild boot` (new generation + boot default, nothing activated) and notifies; otherwise it switches immediately. See `NOTES.md`.

**`portals.nix`** — GNOME portal for `Background` (Packet tray), hyprland portal for ScreenCast/Screenshot/GlobalShortcuts/RemoteDesktop; GNOME portal auto-restarts on crash.

**`greetd.nix`** — `greetd` + `tuigreet` TTY greeter and its TTY `serviceConfig`.

**`power.nix`** — `powerManagement.enable` + `services.fstrim.enable` (SSD trim). thermald is host-specific (foxyNix, Intel) and lives in that host's `system/default.nix`.

**`removable-media.nix`** — UDisks2 daemon (udiskie talks to it over D-Bus to auto-mount) + gVFS (Yazi SFTP mounts under `/run/user/1000/gvfs`). `boot.supportedFilesystems` (exfat + ntfs3) is host-specific.

**`desktop.nix`** — dbus-broker, logind power key handling (`HandlePowerKey = "ignore"`), system-wide Hyprland (`programs.hyprland`), session env vars (`WLR_NO_HARDWARE_CURSORS`, `NIXOS_OZONE_WL`). Active Hyprland config: `home/files/hyprland.lua`.

**`virtualisation.nix`** — Docker + Flatpak.

**`graphics.nix`** — `hardware.graphics.enable` (OpenGL). NVIDIA-specific config stays host-specific in theConstruct's `gpu.nix`.

**`system-packages.nix`** — Shared system packages (vim, wget, git, curl, htop, pulseaudio, pavucontrol) and the `unlock-session` recovery script.

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
- udiskie auto-mount of removable media (USB/SD/external drives)
- Deploys dotfiles: `~/.screenrc`, `~/.config/hypr/hyprland.lua`

### `home/packages.nix` — Shared User Packages

| Category | Packages |
|---|---|
| **Communication** | obsidian, discord, signal-desktop (unstable), firefox, chromium, enpass |
| **Fonts** | FiraCode, JetBrains Mono, Meslo LG (Nerd Fonts) |
| **System Tools** | networkmanagerapplet, pavucontrol, pamixer, playerctl, fastfetch, nwg-look, tree, btop, eza, bat, brightnessctl |
| **Hyprland Ecosystem** | hyprlock, hypridle, hyprshot, fuzzel, kitty, hyprpaper, wlogout |
| **File Sharing** | packet (native Android Quick Share client) |
| **Utilities** | fzf, screen, libnotify, swaynotificationcenter, wtype (Moonlight key injection), unzip |
| **Yazi Deps** | ffmpegthumbnailer, jq, poppler, fd, ripgrep |
| **Electron/Chromium support** | glib (gio for SFTP), expat, libxshmfence, libGL |
| **Other** | sshfs |

### Home Modules (`home/modules/`)

#### `appearance.nix` — GTK/Qt/Kitty/Wofi Theming
- **GTK**: Adwaita-dark theme, Papirus-Dark icons
- **Qt**: Forces GTK3 platform theme + adwaita-dark style
- **Cursor**: Bibata-Modern-Classic (24px)
- **Kitty**: Cyberpunk-Neon theme, font from `theme.json`, opacity from `theme.json`, `shell_integration = "disabled"` (fixes broken Enter key in SSH/local shells)
- **Wofi**: Custom CSS using `theme.json` colors

#### `hyprland.nix` — Window Manager scripts + hyprpaper (NOT home-manager module)

**The home-manager hyprland module is NOT used.** Hyprland is enabled system-wide via `programs.hyprland` in `common/configuration.nix`. The entire Hyprland config is in `home/files/hyprland.lua` (Lua format).

This module only handles:
- Defining the `hyprland-session.target` user target (waybar, hypridle, … bind to it)
- Deploying helper scripts via `writeShellScriptBin` (available on PATH):
  - `goto-workspace` / `pick-wallpaper` — per-workspace wallpaper switching
  - `dpms-off`: display off, but skips while media is playing (MPRIS via `playerctl`). Currently unused: automatic blanking is disabled (see `hypridle.nix`), turn the screens off by hand
  - `dpms-on`: turn the display back on by hand. It also runs `hyprctl reload` when the outputs are stuck at `0x0`, but that reload does NOT reliably restore the modes (measured), so it is not a repair
  - `resume-guard`: post-resume, enable DPMS and restart hyprlock if it died while holding the lock (nvidia Xid 13 / SIGABRT on resume), so the session is never left locked with no lock surface
- Deploying the `hyprpaper.conf` (splash only; wallpapers are applied per output by `set-wallpaper` from the Lua autostart and from `goto-workspace`)

#### `home/files/hyprland.lua` — The Main Hyprland Config (Lua)

**File:** `home/files/hyprland.lua`

Complete Hyprland configuration using the native Lua `hl.*` API. This replaces the old hyprlang settings in `home/modules/hyprland.nix`.

**Structure:**
| Section | API | Details |
|---|---|---|
| Monitor | `hl.monitor({...})` | Default auto-detect; overridden by host's `hypr-host.lua` |
| Autostart | `hl.on("hyprland.start", ...)` | Systemd activation, nm-applet, blueman, hyprpaper, wallpaper |
| Env vars | `hl.env(...)` | PLAYWRIGHT_BROWSERS_PATH, HOME, cursor |
| Look & feel | `hl.config({ general, decoration, misc })` | Gaps, borders, rounding, opacity, blur, shadow |
| Input | `hl.config({ input })` | Keyboard layout `us+altgr-intl` |
| Animations | `hl.curve()`, `hl.animation()` | Custom bezier, default animations |
| Keybinds | `hl.bind(...)` | See keybinds table below |
| Window rules | `hl.window_rule(...)` | Fix XWayland drag issues |

**Host overrides:** Each host's `home/hypr-host.lua` is loaded via `dofile()` in the main config. It can set monitors, workspace rules, touchpad, etc.

**Keybinds:**
| Shortcut | Action |
|---|---|
| `Super + Q` | Open kitty terminal |
| `Super + C` | Close focused window |
| `Super + M` | Exit Hyprland |
| `Super + E` | Open Yazi (in kitty) |
| `Super + V` | Toggle floating |
| `Super + Space` | Fuzzel app launcher |
| `Super + P` | Toggle pseudo-tiling |
| `Super + J` | Toggle split direction (needs `dwindle.preserve_split`) |
| `Super + F` | Fullscreen |
| `Super + L` | Lock screen (`hyprlock`; idle locking via hypridle, idle DPMS disabled) |
| `Menu` | Inject a real Super keypress via `wtype` (Moonlight streaming; synthetic `send_shortcut` events are ignored by games) |
| `Super + Shift + W` | Pick wallpaper (fuzzel picker) |
| `Super + Shift + R` | Reload config: re-runs the file with `dofile` (`hyprctl reload` is a no-op under the Lua provider — measured) |
| `Super + Shift + S` | Enter resize submap (arrows to resize, Shift+arrows to move, Esc to exit) |
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

**No `Alt + Tab`:** hyprshell used to provide a thumbnail switcher on Alt+Tab and an
overview on the Super key. It was removed: the overview opened whenever Super was
pressed. Window switching is `Super + arrows` (movefocus) and `Super + 1..0`.

**Autostart:** Systemd session activation → nm-applet → blueman-applet → hyprpaper → packet (2s) → goto-workspace 1 → kitty (ws1) → yazi (ws3, 3s) → btop (ws10, 4s)

**Host-specific autostart** (in `hypr-host.lua` via `hl.on("hyprland.start")`):
- theConstruct: Signal + Firefox on workspace 7 with 1/3-2/3 split
- foxyNix: Signal on workspace 6

**Custom Scripts:**
- `goto-workspace` — Changes workspace AND sets a random per-workspace wallpaper (cached in `~/.cache/workspace-wallpapers`)
- `pick-wallpaper` — Wofi-based wallpaper picker, shows cleaned-up names (strips "otherland-" prefix), saves per-workspace
- `dpms-off` — display off with media guard, currently unused (see hypridle section)
- `dpms-on` — turn the display on by hand, plus a config reload when the outputs are stuck at `0x0` that is known not to be reliable (see hypridle section)
- `resume-guard` — post-resume: enable DPMS, and restart hyprlock if it crashed while holding the lock (see hypridle section)
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
- Aliases: `v` (nvim), `conf` (open config), `ls` (eza), `cat` (bat)
- Ctrl+Left/Right word jump in zsh
- `rebuild` / `update` are defined in `flake-aliases.nix`, not here

#### `flake-aliases.nix` — Shared `rebuild` / `update` Aliases
Defines the two flake aliases once and assigns them to **both** bash and zsh, so the
shells cannot drift:
- `rebuild` — `pushd "$(nixos-config-dir)" && git add -A && sudo nixos-rebuild switch --flake .#$(hostname) && popd`
- `update` — `nix flake update`, then commits **only** `flake.lock` (and only if it changed),
  then rebuilds — the same commit behaviour as `systemd.services.nix-flake-update`

#### `hyprlock.nix` — Lockscreen
Otherland-themed lock screen:
- "OTHERLAND: $TIME" in large font
- "SIMULATION LEVEL: STABLE" subtitle
- Blurred screenshot background
- Input field says "simulation access code required"
- All colors from `theme.json`

#### `hypridle.nix` — Auto-Sleep System
- `lock_cmd` = `pidof hyprlock || hyprlock` — runs when D-Bus lock event received
- `hypridle.service` sets `KillMode=process`: `lock_cmd` spawns hyprlock inside hypridle's cgroup, so the default control-group kill made `systemctl --user stop/restart hypridle` kill the lock screen and silently unlock the session
- 5 min inactivity → `loginctl lock-session` → D-Bus lock → `lock_cmd` runs hyprlock
- The lock listener deliberately has **no** `ignore_inhibit`: hypridle skips an inhibited listener, so a game or a video holds the idle lock off instead of being interrupted. `Super+L` and the lock-before-suspend path still lock on demand
- **No idle-suspend listener.** Suspend is manual only (`systemctl suspend`). The GPU half is fixed (`powerManagement.enable` removed the `NVRM: Xid 13` errors and black screens), but every resume so far has come back with `hyprctl -j devices` empty, the same libseat/logind seat-toggle bug as a VT switch, so an unattended auto-suspend would leave the machine unusable
- **The 5.5 min (330s) `dpms-off` listener is disabled.** Measured: a SHORT `hl.dsp.dpms()` off/on cycle is harmless, but a LONG off (around 10 minutes, long enough for the monitors to power down for real) leaves both outputs at `0x0` on wake (`failed to commit: Invalid argument`). hyprlock then only receives zero-size configures, so it holds the lock and draws nothing and the screen looks frozen. `hyprctl reload` does NOT reliably restore those modes, so there is no safe automatic repair. Prefer the monitor's own power button over `dpms-off`
- `dpms-off` still checks `playerctl` first — if media is Playing it exits without touching the display
- Manual `Super+L` → runs `hyprlock` directly (no logind roundtrip)
- Before suspend → `loginctl lock-session`; after resume → `resume-guard`, which enables DPMS and restarts hyprlock if it died while holding the lock (nvidia `Xid 13` on resume made hyprlock SIGABRT at `hyprlock.cpp:414` and left Hyprland locked with no lock surface)

#### `neovim.nix` — Text Editor
- Neovim with vi/vim aliases
- LSP packages: `lua-language-server`, `nil` (Nix LS)
- Clipboard: `xclip`

#### `yazi.nix` — Terminal File Manager
- Hidden files shown by default
- Custom keybinds: `M` to mount SFTP via `gio mount`, `g v` to go to GVfs mounts, `g d` to jump to udiskie-mounted removable drives (`/run/media/thebeardbe`)
- `y` shell wrapper alias
- Preview support for videos (ffmpegthumbnailer), JSON (jq), PDFs (poppler)

#### `udiskie.nix` — Removable Media Auto-Mount
- Auto-mounts USB sticks / SD cards / external drives on insertion (udisks2 backend, polkit prompts)
- Notifies on mount/unmount; tray icon only appears while a device is present
- Browse the mounts in Yazi with `g d`

#### `agent.nix` — Pi Coding Agent (SDK Integration)
- Node.js + npm
- `~/.npm-global/bin` in PATH, npm prefix set to `~/.npm-global`
- Settings from `home/files/agent/settings.json` (provider: deepseek, model: deepseek-flash, thinking: high)
- Auth.json deployed from private secrets on first install

#### `secrets.nix` — Secret Option Declarations
Declares `mySecrets.piAuth` option (nullable string). Values provided by the optional `nix-secrets` flake input.

#### `audio.nix` — JBL USB Headset ALSA Fix

**File:** `home/modules/audio.nix` (home-manager; not the system module `common/modules/audio.nix`)

Deploys `~/.config/wireplumber/wireplumber.conf.d/99-jbl-period.conf`, a WirePlumber
rule matching `alsa_output.usb-JBL.*` and `alsa_input.usb-JBL.*`:

```conf
api.alsa.period-size = 1024
api.alsa.headroom    = 8192
```

JBL Quantum dongles (360X, 360, 350) open their ALSA node with a 1 ms period
(48 frames at 48 kHz) on a 32768 frame buffer. PipeWire cannot feed that from a
1024 frame graph, the stream underruns instantly, `snd_pcm_recover` never restarts
it, and ALSA stays in XRUN: silence, `snd_pcm_avail after recover: Broken pipe`
every 2 s, and any player stalling on that device. The rule forces
`period_size 512` and the device works.

Apply without a reboot with
`systemctl --user restart wireplumber pipewire pipewire-pulse`.
Verify with `head -1 /proc/asound/card1/pcm0p/sub0/status` (`RUNNING`, not `XRUN`)
and `awk '/period_size/{print}' /proc/asound/card1/pcm0p/sub0/hw_params`.

Investigation and evidence live outside the repo in
`Documents/agent-notes/audio/jbl-quantum-xrun.md`.

#### `battery-monitor.nix` — Battery Alerts

**File:** `home/modules/battery-monitor.nix`

Systemd user timer that checks battery level every 2 minutes:
- **10%**: Low urgency notification, 5s timeout
- **5%**: Critical urgency, persistent notification
- Only fires when discharging (not on charger)

---

## 6. Host: theConstruct (Desktop)

**Hardware:** AMD Ryzen 5600 + NVIDIA RTX 3060 Ti
**Role:** Gaming / workstation

### System (`hosts/theConstruct/system/`)

**`default.nix`:**
- Hostname: `theConstruct`
- Bootloader: GRUB with EFI support + OS prober (Windows dual-boot)
- exfat + ntfs3 filesystem support (`boot.supportedFilesystems`)
- 7 auto-mounted data drives (all with `nofail` — don't block boot):
  - `/mnt/golden-city` (exfat, B89B-399D)
  - `/mnt/blue-fire` (exfat, 8CB1-7A97)
  - `/mnt/black-glass` (exfat, 32CA-F4E4)
  - `/mnt/silver-light` (exfat, BAE0-0704)
  - `/mnt/middle-country` (NTFS, F270574F705719A5)
  - `/mnt/the-other` (NTFS, 368035BA80358203). The Windows volume, now shrunk to 350 GiB; shrinking leaves the filesystem UUID alone, so this entry is unchanged
  - `/mnt/the-grail` (ext4, b4875096-b8f3-4d96-9ff0-ef04476420cb, 580.9 GiB, mounted with `nofail`). Model storage for the llama.cpp stack plus general data; addressed by UUID in the config, not by device path, because the NVMe device names on this machine have swapped between boots
- Packet Quick Share firewall ports: 9300/tcp, 27000-27009 tcp+udp, 5353/5355 udp

**`gpu.nix`:** NVIDIA config
- `nvidia` video driver (proprietary, not open)
- Modesetting enabled
- `nvidia_drm.modeset=1` kernel param
- 32-bit graphics enabled (for Steam/Proton)
- Stable driver package
- `nvidia-vaapi-driver` for hardware video decode in Steam/Chromium
- `powerManagement.enable = true`: installs `nvidia-suspend` / `nvidia-resume` / `nvidia-hibernate` and sets `NVreg_PreserveVideoMemoryAllocations=1`. Required on this machine, otherwise the driver throws `NVRM: Xid 13` graphics exceptions in clients on resume and hyprlock aborts while holding the lock. `finegrained` stays off; that is for laptop runtime power

**`steam.nix`:** Gaming stack
- Steam with Remote Play + dedicated-server firewall + protontricks
- gamescope + gamemode enabled system-wide (used by Steam/Heroic)
- **Sunshine** game streaming host (`capSysAdmin` for Wayland/KMS capture, firewall open) — Moonlight client on foxyNix connects here

**`llama.nix`:** Runtime prerequisites for the local llama.cpp container stack (compose file and presets live in `home/files/llama/`)
- `hardware.nvidia-container-toolkit.enable`: generates the CDI spec so dockerd can resolve the container's `nvidia.com/gpu=all` device. The legacy `virtualisation.docker.enableNvidia` runtime wrapper is not used (both Docker and the toolkit are CDI based)
- Docker data root moved to `/home/docker` (`virtualisation.docker.daemon.settings."data-root"`): `/` has ~19 GB free, which is not enough for the CUDA image, its layers and the model cache
- `systemd.services.docker.unitConfig.RequiresMountsFor = "/home/docker"` plus a `systemd.tmpfiles` rule, so dockerd creates the data root with root-only permissions after `/home` is mounted instead of writing to `/` first

### Home (`hosts/theConstruct/home/`)

**`default.nix`:**
- Forces smaller GTK font (10px) for ultrawide
- Forces smaller kitty font (9px)
- Removes backlight and bluetooth from Waybar (desktop has no battery/backlight)
- Deploys `hypr-host.lua`

**`hypr-host.lua`:**
- Dual monitor: DP-2 (1920x1080@165, gaming), DP-1 (3440x1440@60, ultrawide)
- Workspaces 1-6 → DP-2, workspaces 7-10 → DP-1 (ws7 moved to ultrawide)
- Window rules: Signal + Firefox on workspace 7 with 1/3-2/3 split
- Autostart: Signal at 5s, Firefox at 7s, setsplitratio at 12s
- **Sets DP-2 as the XWayland XRandR primary at session start**, retrying until XWayland is up. DP-1 sits at negative coordinates, so XWayland places it at X11 `+0+0` and Wine/Proton treats the ultrawide as the primary display: games with no display selector fullscreen there, and on a DP-2 workspace the window and the game disagree about the resolution so clicks land in the wrong place. `xrandr` is provided by this host's `home/packages.nix`. Per-game override for a title that belongs on the ultrawide, as a Steam launch option: `xrandr --output DP-1 --primary ; %command%`

**`packages.nix`:** steam-run, mangohud, prismlauncher, heroic (Heroic Games Launcher), p7zip

---

## 7. Host: foxyNix (Laptop)

**Hardware:** Intel laptop
**Role:** Daily driver

### System (`hosts/foxyNix/system/`)

**`default.nix`:**
- Hostname: `foxyNix`
- Touchpad enabled (`mySystem.touchpad.enable = true`) — X11 libinput fallback
- exfat + ntfs3 filesystem support (`boot.supportedFilesystems`)
- thermald enabled (`services.thermald.enable`) — Intel CPU thermal daemon
- Bootloader: systemd-boot with Ubuntu dual-boot entry
- Silent boot: plymouth, quiet splash, reduced log levels
- Latest Linux kernel (`linuxPackages_latest`)
- Packet Quick Share firewall ports (9300/tcp, 27000-27009 tcp+udp, 5353/5355 udp)

**`steam.nix`:** Steam enabled with Remote Play firewall open

### Home (`hosts/foxyNix/home/`)

**`default.nix`:**
- Deploys `hypr-host.lua`

**`hypr-host.lua`:**
- Monitor: eDP-1 at preferred resolution, scale 1.0
- Touchpad: natural_scroll=true, tap_to_click=true, disable_while_typing=true
- Window rule: Signal on workspace 6
- Autostart: signal-desktop at 6s

**NOTE:** Touchpad options use Lua API names (tap_to_click), not hyprlang names (tap).

**`packages.nix`:** `moonlight-qt` (from **unstable** — main nixpkgs FFmpeg 9 broke the 6.1.0 build; unstable provides it against FFmpeg 8.1.2) — game streaming client (connects to Sunshine on theConstruct)

---

## 8. Additional Files

### `.pi/skills/nixos-hyprland/`
Pi coding agent skill providing:
- `SKILL.md` — Skill manifest with Lua API reference, verify script invocation
- `references/hyprland-lua-api.md` — Complete `hl.*()` API reference (monitor, config, bind, curve, animation, window_rule, layer_rule, on, env, exec_cmd, dsp, gesture, etc.)
- `references/nixos-patterns.md` — NixOS patterns for Lua config, host overrides, waybar, hyprlock, hypridle
- `references/troubleshooting.md` — Common issues and solutions
- `scripts/verify-config.sh` — Validates Lua config syntax and common mistakes

### `recovery-scripts/unlock-session`
Standalone recovery tool for a locked session that cannot be unlocked. Installed system-wide as `unlock-session` (wired into `common/modules/system-packages.nix` via `environment.systemPackages`). Run it from a free TTY (Ctrl+Alt+F2), then return with Ctrl+Alt+F1. It does five things:

1. Builds `HYPRLAND_INSTANCE_SIGNATURE` from `hyprctl instances`, since a plain TTY does not have it
2. Runs `loginctl activate` on the tty1 session, because Hyprland only commits DRM changes while its session is the active VT
3. Kills a hung `hyprlock` (`hypridle`'s `lock_cmd` is `pidof hyprlock || hyprlock`, so a stale process blocks the next lock)
4. Runs `hyprctl repl 'return hl.clear_crashed_lockscreen()'`. This is what actually releases the lock: `loginctl unlock-session <ID>` only moves logind's `LockedHint`, it does not clear Hyprland's ext-session-lock state
5. Runs `hyprctl reload` to re-modeset outputs stuck at `0x0`, then prints the monitor state; if they are still `0x0` it points at `loginctl terminate-session <ID>`

Background, two failure modes end up here:

- hyprlock dies while holding the lock (0.9.5 aborted on Wayland protocol errors during DPMS wake: `wl_display#1: error 0: invalid object`; 0.9.6 no longer aborts but can still be left with unusable surfaces). Hyprland keeps the session locked with no lock surfaces to draw.
- After a LONG DPMS off (around 10 minutes, monitors actually powered down) the nvidia driver + aquamarine mark both outputs disconnected (`Cannot commit a disconnected output`, `atomic drm request: failed to commit: Invalid argument`), the monitors fall back to `0x0`, and a running hyprlock only receives zero-size configures: it holds the lock, grabs input and draws nothing. `hyprctl reload` does NOT restore these modes (measured), so the automatic DPMS listener is disabled (see `hypridle.nix`) and screens are turned off by hand. A short DPMS off/on cycle does not trigger this.
- Separately, a **VT switch** toggles the libseat/logind seat and the session can come back with **no input devices**: `hyprctl -j devices` is empty while the kernel still has the devices and the user can open them from a shell. Neither a VT cycle nor a `udevadm trigger` restored them; only a compositor restart does. Check `hyprctl devices` before declaring a session usable.
- **Suspend/resume has the same input failure.** With `hardware.nvidia.powerManagement.enable = true` the `nvidia-suspend`/`nvidia-resume` services run and the `NVRM: Xid 13` graphics exceptions and black screens are gone, but the resume still ends with no input devices. `resume-guard` (`after_sleep_cmd`) cannot help: Hyprland stays alive, it simply holds no input devices. Idle suspend is deliberately not configured; suspend manually only

No upstream fix yet, so these scripts are the workaround.

### `home/files/agent/settings.json`
Pi coding agent default settings:
```json
{
  "packages": ["npm:pi-web-access"],
  "defaultProvider": "deepseek",
  "defaultModel": "deepseek-flash",
  "defaultThinkingLevel": "high",
  "theme": "dark",
  "hideThinkingBlock": false
}

```

### `home/files/screenrc`
GNU Screen config with vim-style tab navigation (Ctrl+A + h/j/k/l) and 4 initial tabs.

### `home/files/llama/`
Local llama.cpp router on CUDA for theConstruct's RTX 3060 Ti. Both repo files are deployed to `~/.config/llama/` on **theConstruct only** (not on foxyNix, since the GPU device and the model directory are host-local), and they are the whole definition of the container: the lifecycle is manual, nothing starts the container at boot, and it is started and stopped with the `llama` command (`llama up | stop | down | restart | status | logs | help`), a `writeShellScriptBin` in `hosts/theConstruct/home/packages.nix` that wraps `docker compose` against this file (`restart: "no"`).

- `compose.yaml` — the container: `ghcr.io/ggml-org/llama.cpp:server-cuda`, the CDI GPU device, the `mmap+mlock` limits for CPU-resident experts, and the router flags (one resident model, explicit loading only, flash attention, 8-bit KV cache)
- `models.ini` — per-model presets passed to `--models-preset` (context size, `n-gpu-layers`, `n-cpu-moe`, batch sizes, `reasoning-budget`). Numbers are tuned against context length rather than decode speed: context sizes are driven by the `pi` agent's baseline prompt rather than by the model, and the `n-cpu-moe` values are the VRAM-for-speed trade that pays for them. Each context is bounded by its model's trained context (131072 and 262144), and every context size is now measurement-backed: both were raised until a load succeeded or failed, so the KV-cache cost per token is known rather than projected. The two figures differ for one reason: the Gemma 4 models use sliding-window attention, which costs 13.2 MiB of KV per 1024 tokens on the E4B, whereas the Qwen uses full attention and costs 51.0 MiB, so the same VRAM buys roughly four times less context on the Qwen (180224 was measured to fail there while allocating a 8976 MiB KV cache, which is why its preset stops at 81920). `reasoning-budget` caps how much of a reply the model may spend thinking, so a long think cannot consume the client's whole output budget and return an empty answer. No model is loaded at startup

Port `21434` is published twice: on loopback (`127.0.0.1`) for the local agent on theConstruct, and on the reserved LAN address `192.168.100.12` for other devices on the home network. The LAN address is a DHCP lease with a router reservation, so it is always assigned, and binding it is only safe because the container is started by hand (by then the address exists; Docker refuses to start on a missing published address). It is never published on `0.0.0.0`. Published ports bypass the NixOS INPUT chain because Docker DNATs them first, so `networking.firewall` cannot filter them and the API key is the access control for both bindings. Models live in `/mnt/the-grail/llama-models` (mounted read-write as `/models`), on the dedicated ext4 data partition rather than in `/home`, and the presets are mounted read-only. `LLAMA_BASE_URL=http://127.0.0.1:21434` is exported on theConstruct only (see `hosts/theConstruct/home/default.nix`), for the pi agent's llama.cpp provider.

**API key.** The server requires authentication. Two files are generated by the `generateLlamaApiKey` home-manager activation and mounted read-only:

- `~/.config/llama/api-key` → `/run/secrets/llama-api-key`, passed as `--api-key-file`, so the key never appears in the process table or `docker inspect`. A missing file stops the server instead of leaving it unauthenticated.
- `~/.config/llama/ui-config.json` → `/run/secrets/llama-ui-config.json`, passed as `--ui-config-file`. It is `{"apiKey": "<the key>"}`, rewitten on every activation from the key file, so the web interface at `:21434` is usable without typing the key. `--ui-config-file` (not inline `--ui-config`) keeps the value out of the process table for the same reason.

Both files are 0600, local-only: never committed and never copied into the Nix store. Rotate by deleting `api-key`, rebuilding (the activation only ever creates it, so it regenerates, and the ui-config is rewritten to match), then re-running the pi agent's `/login` for the llama.cpp provider.

**Tailnet exposure.** The tailnet reaches the stack through `tailscale serve`, declared as the `tailscale-serve-llama` systemd oneshot in `hosts/theConstruct/system/llama.nix` (`tailscale serve --bg --tcp=21434 tcp://127.0.0.1:21434`), not by publishing the Tailscale address. This path exists so remote nodes do not depend on the home LAN, and it is declared system-side rather than as a port binding because the Tailscale address can legitimately be absent, and Docker would then refuse to start the whole container, loopback binding included. The plain-TCP form is used because the default HTTPS form needs HTTPS certificates enabled for the tailnet in the admin console, which this tailnet does not have; raw TCP needs no certificate. The serve listener binds port `21434` on the tailnet, so `networking.firewall.interfaces.tailscale0.allowedTCPPorts` opens only that port (trusting the interface would expose ssh and every other listener). The proxy is lazy: a stopped container yields a gateway error from the tailnet while the exposure stays up.

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
| Add a system package | `common/modules/system-packages.nix` → `environment.systemPackages` |
| Add a user package | `home/packages.nix` |
| Add a Hyprland keybind | `home/files/hyprland.lua` → `hl.bind(...)` section |
| Change Hyprland appearance (gaps, blur, etc.) | `home/files/hyprland.lua` → `hl.config({ general, decoration })` |
| Change Waybar layout | `home/modules/waybar.nix` → `settings.mainBar` |
| Change wallpaper | `set-wallpaper <path>` (per output, called by `home/files/hyprland.lua` autostart and `goto-workspace`) |
| Add a new machine | Create `hosts/<name>/`, add to `flake.nix` `nixosConfigurations` |
| Change lock screen text | `home/modules/hyprlock.nix` |
| Add GTK theme | `home/modules/appearance.nix` → `gtk.theme` |
| Change shell prompt | `home/modules/starship.nix` |
| Change `rebuild` / `update` aliases | `home/modules/flake-aliases.nix` |
| Enable secrets | Uncomment `nix-secrets` in `flake.nix`, create private flake |
| Adjust Nix GC strategy | `common/modules/nix-gc.nix` → `systemd.services.nix-gc-tiered` |
| Change auto-update schedule | `common/modules/flake-update.nix` → `systemd.timers.nix-flake-update`; enable per host with `mySystem.flakeUpdate.enable` (exactly one updater) |
| Recover a stuck locked screen | `unlock-session` (script source: `recovery-scripts/unlock-session`) |
| Change keyboard layout | `home/files/hyprland.lua` → `hl.config({ input = { kb_layout, kb_variant } })` |
| Toggle touchpad | `common/modules/touchpad.nix` for X11, or host's `hypr-host.lua` for Hyprland |
| Add a new wallpaper | Drop in `wallpapers/`, copy to `~/Pictures/Wallpapers/`, pick via `Super+Shift+W` |
| Change monitor layout | Host's `hypr-host.lua` → `hl.monitor({...})` |
| Change window splitting | `home/files/hyprland.lua` (dwindle `preserve_split`, `Super + J`) |
| Change the launcher | `home/modules/appearance.nix` (fuzzel) + `hl.bind` in `hyprland.lua` |
| Change bootloader | Host's `system/default.nix` → `boot.loader` |

---

## 10. Rebuild Flow

```
1. Edit file(s) in the repo checkout
2. (Optional) git add + git commit
3. sudo nixos-rebuild switch --flake .#$(hostname)
4. Aliases (home-manager, defined once in `home/modules/flake-aliases.nix` for both shells):
   - `rebuild` = `pushd "$(nixos-config-dir)" && git add -A && sudo nixos-rebuild switch --flake .#$(hostname) && popd`
   - `update` = `nix flake update`, commit `flake.lock` if it changed, then the same rebuild
```

---

## 11. Config Format: Lua vs hyprlang

The Hyprland config is written in **Lua** (`home/files/hyprland.lua`) using the native `hl.*` API. This is the format that Hyprland 0.55.x uses natively — passing configs via `eval hl.dispatch(...)` requires the Lua config manager to be active.

### Why Lua instead of hyprlang?

1. **Layout messages** — `Super + J` sends `hl.dsp.layout("togglesplit")` through
   `hyprctl`, because binding the Lua layout dispatcher directly registers a
   `__lua` dispatcher that never reaches dwindle (a silent no-op).
2. **Future-proof** — Hyprland is moving toward Lua as the primary config format.

### How it works

1. `greetd` launches `Hyprland -c ~/.config/hypr/hyprland.lua` (set in `common/modules/greetd.nix`)
2. The Lua config loads and calls `hl.monitor()`, `hl.config()`, `hl.bind()`, etc.
3. At the top of the main Lua file, it loads host-specific overrides with `dofile("~/.config/hypr/host.lua")`
4. `~/.config/hypr/hyprland.lua` is deployed as a **real file** (copied by a home-manager activation), not a store symlink: Hyprland resolves the `-c` path once at startup, so a symlink would pin it to the generation that was current at login
5. `hyprctl reload` is a **no-op** with the Lua config provider (measured: an option change survives a reload unchanged), so `Super+Shift+R` re-runs the file with `dofile`. Every binding goes through a `bind()` helper that calls `hl.unbind(key)` first, which is what keeps repeated reloads idempotent (Hyprland keeps an existing bind instead of replacing it, and the first match wins). Submap binds use the helper too, but their global entry key is registered *after* `define_submap`, because `hl.unbind` ignores the submap context and the two would otherwise remove each other

---

## 12. Window switching

There is no Alt+Tab switcher. hyprshell provided one (plus an overview on the
Super key) and was removed because the overview kept appearing whenever Super was
pressed. Switching windows is:

| Key | Action |
|---|---|
| `Super + arrows` | Move focus to the window in that direction |
| `Super + 1..0` | Focus a workspace (via `goto-workspace`, which also sets the wallpaper) |
| `Super + Shift + 1..0` | Move the focused window to a workspace |

---

## 13. Quick Reference

| Command | What it does |
|---|---|
| `sudo nixos-rebuild switch --flake .#theConstruct` | Build and switch to new generation |
| `sudo nixos-rebuild test --flake .#theConstruct` | Test without making permanent |
| `sudo nixos-rebuild boot --flake .#theConstruct` | Build and set as boot default, without activating (use for kernel/NVIDIA changes) |
| `rebuild` / `rebuild-boot` | Aliases for the two above against `$(hostname)` |
| `os-update-status` | Show an update staged by the weekly check, and whether it needs a reboot |
| `llama up` / `stop` / `status` / `logs` | Control the local llama.cpp container |
| `sudo nix-collect-garbage -d` | Clean up old store paths |
| `nix-env --list-generations -p /nix/var/nix/profiles/system` | List boot entries |
| `sudo nix-env --delete-generations -p /nix/var/nix/profiles/system <N>` | Remove specific generation |
| `hyprctl reload` | No-op under the Lua config provider (measured); use the Lua reload below |
| `Super + Shift + R` | Re-run the config file (`dofile`) with reload-safe binds |
| `set-wallpaper <path>` | Change wallpaper on every output (hyprpaper 0.8 requires a monitor name; the empty-monitor form is a no-op) |
| `Super + Shift + W` | Interactive wallpaper picker |
| `Super + Space` | Fuzzel app launcher |
| `Super + L` | Lock screen (`hyprlock`) |
| `Super + Shift + S` | Enter resize submap (arrows to resize, Shift+arrows to move, Esc to exit) |
| `nm-applet` | NetworkManager tray |
| `blueman-applet` | Bluetooth tray |
| `hyprshot -m output` | Screenshot full screen |
| `hyprshot -m window` | Screenshot active window |
| `hyprshot -m region` | Screenshot selected area |
| `Super + Shift + P` | Screenshot selected region |
| `Super + Ctrl + P` | Screenshot active window |
| `Super + Alt + P` | Screenshot full screen |
| `Menu` | Inject Super key (Moonlight streaming) |
| `unlock-session` | Unlock a logind session stuck after a hyprlock crash (from a free TTY) |
| `wlogout` | Power menu |
| `btop` | Resource monitor (click battery in Waybar) |
| `pavucontrol` | Audio profile GUI (click volume in Waybar) |
| `pactl list cards` | List audio devices for profile switching |
| `overskride` | Bluetooth manager (click Bluetooth in Waybar) |
| `swaync-client -op` | Open notification center (click bell in Waybar) |
| `proton mail messages list --unread` | List unread Proton mail |
| `proton calendar events list` | List Proton calendar events |
| `proton drive items list /Documents` | List a Proton Drive folder |
| `proton-push <dir> <remote>` | Upload a file/dir to Proton Drive |
| `proton-pull <remote> <dir>` | Download a file/dir from Proton Drive |

---

## 14. Result Symlink

A `result` symlink only appears at the repo root when building with `nix build` (not `nixos-rebuild switch`). To inspect the live system use `/run/current-system`, or list generations with `nix-env --list-generations -p /nix/var/nix/profiles/system`.

---

## 15. Proton Tooling (Mail, Drive, Calendar, Contacts)

**Tool:** [`proton-cli`](https://github.com/roman-16/proton-cli) by roman-16 — an unofficial, community, single-binary CLI covering the whole Proton suite. It uses Proton's own `go-srp`/`gopenpgp` for login and encryption, but it is **not affiliated with Proton AG and is unaudited**.

### Where it comes from
- Flake input `proton` → `github:roman-16/proton-cli/v5.0.1` (pinned to the tag).
- nixpkgs lags badly (`2.2.3` vs upstream `5.x`), hence the upstream pin.
- Built from source via `buildGoModule`; exposed to home modules as `protonCli` (in `extraSpecialArgs`).

### What is installed (`home/modules/proton.nix`)
| Command | Purpose |
|---|---|
| `proton` / `proton-cli` | Mail, Drive, Calendar, Contacts, `account`, raw `api` |
| `proton-push <local> <remote>` | Upload a file/dir to Drive (`--if-exists replace`, keeps a revision) |
| `proton-pull <remote> <localdir>` | Download a file/dir from Drive (`--recursive --dest-dir`) |

`proton-push`/`proton-pull` are thin wrappers only — no sync, no conflict detection, no watcher. Re-running a push re-uploads.

### Agent skill
`home/files/agent/skills/proton-cli/SKILL.md` deploys to `~/.pi/agent/skills/proton-cli/` (handled by `agent.nix`). It instructs the agent to run `proton skill --body-only` first, so it always follows the installed build's own authoritative command reference instead of remembered syntax.

### Sign in (manual, per machine/profile)
```bash
proton account login                  # default profile
proton account login --profile work   # named profile
proton account sessions list         # see sessions
proton account sessions revoke       # kill a session
```

### Account model (important)
- Proton **Mail/Drive/Calendar** have **no scoped tokens and no delegation** — a session is full-account access.
- Proton **Pass** has scoped tokens, but this setup uses **Enpass**, so Pass is out of scope entirely.
- The only real Proton-side boundary is a **separate Proton account** (usable for Calendar/Drive via sharing), because Mail cannot be shared or delegated.
- `PROTON_CONFIRM` (for example `deletions=deny`) is a **guardrail against accidents**, enforced by the binary itself. It is **not** a security boundary — a hijacked agent could bypass it.
- Real isolation comes from running the agent in a **container** (VM/LXC/Docker), which this setup assumes for anything touching mail.

### Why not rclone, the official CLI, or a mount
- **rclone** Proton Drive backend is Tier 4 (Experimental) and broke repeatedly in 2026 (new-SDK name hashes, API version rejections, upload failures). Not safe for backups.
- The **official Proton Drive CLI** is Drive-only (no Mail/Calendar) and has no mount.
- **Mounting** requires Proton's Linux desktop client, which is announced but not yet released. There is no reliable mount today.

### Re-authentication on a fresh machine
Sessions live in `~/.config/proton-cli/sessions/<profile>.json` (mode `0600`) and are per-machine. A new machine needs `proton account login` again; sessions are not copied between hosts.
