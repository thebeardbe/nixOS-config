# NixOS Patterns Used in This Config

Reference for the NixOS patterns and conventions used throughout this project.

## Flake Architecture

### Inputs
```nix
inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";  # Use same nixpkgs as us
    };
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
};
```

Key patterns:
- `inputs.nixpkgs.follows = "nixpkgs"` — home-manager uses OUR nixpkgs, preventing version mismatches
- `nixpkgs-unstable` — separate channel for bleeding-edge packages (signal-desktop, etc.)
- Optional inputs (nix-secrets) — commented out by default, uncomment when available

### Outputs
```nix
outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, ... }@inputs:
let
    system = "x86_64-linux";
    themeConfig = builtins.fromJSON (builtins.readFile ./theme.json);
    unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };

    mkHost = host: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; unstable = unstable; };
        modules = [
            ./hosts/${host}/default.nix
            home-manager.nixosModules.home-manager
            {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.thebeardbe = { ... }: {
                    imports = [
                        ./home/home.nix
                        ./hosts/${host}/home/default.nix
                    ];
                };
                home-manager.extraSpecialArgs = {
                    inherit unstable;
                    theme = themeConfig;
                };
            }
        ];
    };
in {
    nixosConfigurations = {
        foxyNix      = mkHost "foxyNix";
        theConstruct = mkHost "theConstruct";
    };
};
```

Patterns:
- `themeConfig` — JSON parsed at flake eval time, passed to ALL home-manager modules
- `unstable` — separate nixpkgs import for specific bleeding-edge packages
- `mkHost` — factory function reducing boilerplate per host
- `specialArgs` → available in system modules
- `extraSpecialArgs` → available in home-manager modules
- `useGlobalPkgs = true` — home-manager uses system nixpkgs (consistency)
- `useUserPackages = true` — home-manager manages user's `~/.nix-profile`

## Module System

### Import chains
```
Host's default.nix
├── hardware-configuration.nix   (auto-generated)
├── ../../common/configuration.nix
│   └── common/modules/*.nix     (bluetooth, touchpad, security, hardware, users)
├── system/default.nix           (hostname, bootloader, GPU, steam)
└── home-manager.nixosModules.home-manager
    └── home-manager.users.thebeardbe
        ├── home/home.nix
        │   └── home/modules/*.nix  (hyprland, waybar, starship, etc.)
        │   └── home/packages.nix
        └── hosts/<host>/home/default.nix
            ├── hosts/<host>/home/packages.nix   (host-specific)
            ├── hosts/<host>/home/hypr-host.lua  → deploys to ~/.config/hypr/host.lua
```

### Module function signature
```nix
{ config, pkgs, lib, ... }:     # Standard NixOS module args
{ config, pkgs, theme, ... }:   # Home-manager with extraSpecialArgs (theme)
{ config, pkgs, unstable, ... }: # Home-manager with unstable channel
```

## Passing values through the module system

### Via specialArgs (system-level)
```nix
specialArgs = { inherit inputs; unstable = unstable; };
```
Available in system modules:
```nix
{ config, pkgs, inputs, unstable, ... }: ...
```

### Via extraSpecialArgs (home-manager)
```nix
home-manager.extraSpecialArgs = { inherit unstable; theme = themeConfig; };
```
Available in home-manager modules:
```nix
{ config, pkgs, theme, unstable, ... }: ...
```

## Package management patterns

### System packages (root owned)
```nix
environment.systemPackages = with pkgs; [ vim wget git curl htop ];
```

### User packages (home-manager)
```nix
home.packages = with pkgs; [ discord obsidian firefox ... ];
```

### Unstable packages
```nix
# In flake.nix:
unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };

# In module:
{ unstable, ... }: {
    home.packages = [ unstable.signal-desktop ];
}
```

### Custom scripts as packages
```nix
(pkgs.writeShellScriptBin "goto-workspace" ''
    #!/usr/bin/env bash
    # ...script content...
'')
```
This creates a package that installs the script to `/nix/store/.../bin/goto-workspace`.

## File deployment patterns

### Static dotfiles
```nix
home.file = {
    ".screenrc".source = ./files/screenrc;
    ".config/hypr/hyprland.lua".source = ./files/hyprland.lua;
    ".config/hyprshell/config.toml".source = ./files/hyprshell-config.toml;
};
```

### XDG config files (home-manager managed)
```nix
xdg.configFile."hypr/hyprpaper.conf".source = ./hyprpaper.conf;
```

### Host-specific file deployment
In `hosts/<host>/home/default.nix`:
```nix
{ ... }: {
    home.file = {
        ".config/hypr/host.lua".source = ./hypr-host.lua;
    };
}
```

## Conditional/Optional patterns

### Optional flake inputs (secrets)
```nix
secretModulesFor = host:
    if inputs ? nix-secrets
    then [ inputs.nix-secrets.nixosModules.common
           inputs.nix-secrets.nixosModules.${host} ]
    else [];
```
Then: `modules = [...] ++ secretModulesFor host;`

### Optional options (for secrets)
In `home/modules/secrets.nix`:
```nix
{ config, lib, ... }:
let cfg = config.mySecrets;
in {
    options.mySecrets.piAuth = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Pi agent auth.json contents";
    };
}
```

## Theme system

`theme.json` is the single source of truth for all visual design tokens:
```json
{
    "colors": { "background": "#000b1e", "text": "#c0c0c0", "accent": "#0abdc6", ... },
    "spacing": { "gaps_in": 5, "gaps_out": 10, "border_width": 2, "radius": 10 },
    "font": { "family": "FiraCode Nerd Font", "size": 11 },
    "opacity": 0.92
}
```

It's passed as `theme` extraSpecialArg to home-manager, consumed by:
| Module | What uses theme |
|--------|----------------|
| `appearance.nix` | Kitty font/opacity, Wofi CSS colors, GTK fallthrough |
| `waybar.nix` | RGB color computation for CSS, opacity |
| `hyprlock.nix` | Colors for lock screen elements, font family |
| `starship.nix` | Prompt colors |

## Service patterns

### greetd (display manager)
```nix
services.greetd = {
    enable = true;
    settings = {
        default_session = {
            command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --user-menu --asterisks --cmd 'Hyprland -c /home/thebeardbe/.config/hypr/hyprland.lua'";
            user = "greeter";
        };
    };
};
```
Key: `--cmd` flag launches Hyprland with Lua config path after login.

### systemd services (home-manager)
```nix
programs.waybar = {
    enable = true;
    systemd.enable = true;  # Managed by systemd --user
};
```

### systemd timers (nix-gc-tiered)
Custom systemd timer + oneshot service for tiered profile cleanup.

## Rebuild commands reference

```bash
# Switch (build + activate now):
sudo nixos-rebuild switch --flake .#$(hostname)

# Test (build + activate temporarily, rollback on reboot):
sudo nixos-rebuild test --flake .#$(hostname)

# Boot (activate on next boot only):
sudo nixos-rebuild boot --flake .#$(hostname)

# Dry-build (evaluate without building):
sudo nixos-rebuild dry-build --flake .#$(hostname)

# Dry-activate (show what would change):
sudo nixos-rebuild dry-activate --flake .#$(hostname)

# Build only (create result symlink, don't switch):
nixos-rebuild build --flake .#$(hostname)

# List generations:
nix-env --list-generations -p /nix/var/nix/profiles/system

# Rollback:
sudo nixos-rebuild switch --rollback

# Garbage collect:
sudo nix-collect-garbage -d

# Check flake:
nix flake check
nix flake show
nix flake metadata
```

## Adding a new package

1. **System package** → `common/configuration.nix` → `environment.systemPackages`
2. **User package (all hosts)** → `home/packages.nix`
3. **User package (specific host)** → `hosts/<host>/home/packages.nix`
4. **Unstable package** → use `unstable.<pkgname>` anywhere

## Adding a new home-manager module

1. Create `home/modules/<name>.nix`
2. Import it in `home/home.nix` → `imports = [ ./modules/<name>.nix ]`
3. Use `{ config, pkgs, theme, ... }:` signature if you need theme

## Adding a new system module

1. Create `common/modules/<name>.nix`
2. Import it in `common/configuration.nix` → `imports = [ ./modules/<name>.nix ]`
