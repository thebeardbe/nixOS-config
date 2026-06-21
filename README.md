# Renaissance Man Unified Config

NixOS + home-manager configuration for a multi-machine setup, themed around the **Otherland** network.

## Machines

| Host | Flake output | Hardware | Role |
|---|---|---|---|
| foxyNix | `.#foxyNix` | Intel laptop | Daily driver |
| theConstruct | `.#theConstruct` | AMD Ryzen 5600 + RTX 3060 Ti | Gaming / workstation |

## Structure

```
├── flake.nx                # Entry point — defines all machines
├── theme.json              # Central colors, fonts, opacity (shared)
├── common/                 # Shared system config
│   ├── configuration.nix
│   └── modules/            # bluetooth, touchpad, users, security, hardware
├── home/                   # Shared home-manager config
│   ├── home.nix
│   └── modules/            # appearance, hyprland, waybar, kitty, starship, etc.
├── hosts/
│   ├── foxyNix/            # Laptop
│   │   ├── default.nix
│   │   ├── hardware-configuration.nix
│   │   └── home/
│   └── theConstruct/       # Desktop
│       ├── default.nix
│       ├── hardware-configuration.nix
│       └── home/
│           ├── default.nix
│           └── gaming.nix
├── wallpapers/
└── secrets/                # Documentation for private secrets setup
```

## Key features

- **Hyprland** — window manager with dynamic workspaces, animations, and per-workspace wallpapers
- **Waybar** — status bar with app icons, system monitoring, and power menu
- **Kitty** — terminal with Cyberpunk-Neon theme
- **WoFI** — custom wallpaper picker with cleaned-up names
- **Lock screen** — Hyprlock with Otherland-themed UI
- **Garbage collection** — tiered Nix store cleanup (7d daily, 1/week monthly, 1/month quarterly)
- **Steam** — enabled on theConstruct with gamescope and remote play
- **Gaming** — MangoHud, PrismLauncher, steam-run

## Install on a new machine

```bash
# Clone
git clone https://github.com/thebeardbe/nixOS-config.git
cd nixos-config

# Generate hardware config (adjust path for your machine)
nixos-generate-config --show-hardware-config > hosts/your-host/hardware-configuration.nix

# Rebuild
sudo nixos-rebuild switch --flake .#your-host
```

## Secrets

Secret values (API keys, tokens, private keys) are handled via a separate **private** `nix-secrets` flake, pulled as a flake input at build time. See `secrets/README.md` for the expected structure.

## Acknowledgments

Built with [home-manager](https://github.com/nix-community/home-manager), [hyprland](https://hyprland.org/), and the NixOS community.
