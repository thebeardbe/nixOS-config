# Hyprland Lua API Reference

Complete reference for the `hl.*` Lua API. Validated against:
- Official wiki: `https://wiki.hypr.land/` (as of 2026-06-30)
- Official example: `github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua`
- Hyprland 0.55.4 running config: `Hyprland --verify-config` passes

## Global variables

| Variable | Description |
|----------|-------------|
| `hl` | The global Hyprland Lua API object |
| `mainMod` | User-defined variable, typically `"SUPER"` |

## hl.monitor()

```lua
hl.monitor({
    output   = "DP-1",           -- "" = auto
    mode     = "preferred",      -- "1920x1080@60", "preferred", "highres", "highrr"
    position = "auto",           -- "0x0", "1920x0"
    scale    = "auto",           -- "auto" or number (1, 1.5, 2)
})
```

## hl.config()

All config in one call or multiple (they merge). Can include sub-sections for layouts:

```lua
hl.config({
    general = {
        gaps_in       = 5,
        gaps_out      = 10,
        border_size   = 2,
        col = {
            active_border   = { colors = {"rgba(0abdc6ff)"} },
            -- Gradient: { colors = {"rgba(33ccffee)","rgba(00ff99ee)"}, angle = 45 }
            inactive_border = "rgba(000b1eaa)",
        },
        allow_tearing = false,
        resize_on_border = false,
        layout        = "dwindle",    -- "dwindle" or "master"
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,
        active_opacity   = 0.95,
        inactive_opacity = 0.75,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",  -- also accepts 0xee1a1a1a
        },
        blur = {
            enabled  = true,
            size     = 3,
            passes   = 1,
            vibrancy = 0.1696,
            xray     = true,
        },
    },

    -- Layout-specific settings
    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
    scrolling = { fullscreen_on_one_column = true },

    input = {
        kb_layout  = "us",
        kb_variant = "altgr-intl",
        follow_mouse = 1,
        sensitivity  = 0,          -- -1.0 to 1.0
        accel_profile = "flat",    -- "flat" or "adaptive"
        touchpad = {
            natural_scroll = true,
            click_method   = "clickfinger",
            tap            = true,
        },
    },

    misc = {
        disable_watchdog_warning = true,
        force_default_wallpaper  = 0,     -- 0 or 1; -1 = show anime girl
        disable_hyprland_logo    = true,
    },

    ecosystem = {
        enforce_permissions = true,   -- requires restart
    },
})
```

### Border Colors

Gradient (two colors with angle):
```lua
col = {
    active_border = { colors = {"rgba(33ccffee)", "rgba(00ff99ee)"}, angle = 45 },
}
```

Single color:
```lua
col = {
    active_border = { colors = {"rgba(0abdc6ff)"} },
}
```

Shadow colors accept both formats: `"rgba(1a1a1aee)"` or `0xee1a1a1a`.

## hl.bind()

`hl.bind(keycombo, dispatcher, options)` — returns a **handle object** with `:set_enabled(bool)`.

```lua
local b = hl.bind("SUPER + C", hl.dsp.window.close())
b:set_enabled(false)  -- disable the bind at runtime
```

### Key names
`SUPER`, `SHIFT`, `CTRL`/`CONTROL`, `ALT`, `left`/`right`/`up`/`down`, `space`, `return`/`enter`, `escape`/`esc`, `backspace`, `tab`, `0`-`9`, `A`-`Z`, `Print`, `XF86Audio*`, `XF86MonBrightness*`, `XF86PowerOff`, `mouse:272` (LMB), `mouse:273` (RMB), `mouse:274` (MMB), `mouse_down`, `mouse_up`

### Options
| Option | Type | Description |
|--------|------|-------------|
| `repeating = true` | bool | Key repeats when held (volume, resize, brightness) |
| `mouse = true` | bool | Mouse binding (required for mouse buttons) |
| `locked = true` | bool | Prevents key from being passed to apps (XF86 keys) |

## hl.dsp.* — Dispatchers

Dispatchers return tables describing actions. They don't execute immediately — feed them to `hl.bind()` or `hl.dispatch()`.

### General (`hl.dsp.`)
| Method | Description |
|--------|-------------|
| `exec_cmd(cmd, rules?)` | Execute via `sh -c`. Rules = table of window rule effects |
| `exec_raw(cmd)` | Execute directly (no shell) |
| `focus({ direction })` | Move focus in a direction (l/r/u/d) |
| `focus({ monitor })` | Move focus to a monitor |
| `focus({ workspace, on_current_monitor? })` | Move focus to a workspace |
| `focus({ window })` | Move focus to a window |
| `focus({ urgent_or_last })` | Focus urgent or last window |
| `focus({ last })` | Focus last window |
| `exit()` | Quit Hyprland |
| `submap(name)` | Enter a submap |
| `pass({ window? })` | Pass shortcut to a window |
| `send_shortcut({ mods, key, window? })` | Send a shortcut to a window |
| `send_key_state({ mods, key, state, window? })` | Send key press/release |
| `layout(message)` | Send layout message (e.g. "togglesplit") |
| `dpms({ action?, monitor? })` | Toggle monitors on/off |
| `event(string)` | Send event to socket2 |
| `global(string)` | Activate dbus global shortcut |
| `force_idle(seconds)` | Set elapsed time for idle timers |
| `no_op()` | Do nothing (for conditional binds) |

### Window (`hl.dsp.window.`)
| Method | Description |
|--------|-------------|
| `close(window?)` | Graceful close |
| `kill(window?)` | SIGKILL the process |
| `signal({ signal, window? })` | Send POSIX signal |
| `float({ action?, window? })` | Set floating state |
| `fullscreen({ mode?, action?, window? })` | Set fullscreen. mode: "maximized"/"fullscreen" |
| `fullscreen_state({ internal, client, action?, window? })` | Precise fullscreen state control |
| `pseudo({ action?, window? })` | Pseudotile |
| `move({ direction, window? })` | Move in direction |
| `move({ workspace, follow?, window? })` | Move to workspace |
| `move({ monitor, follow?, window? })` | Move to monitor |
| `move({ x, y, relative?, window? })` | Move by/to coords |
| `move({ into_group = direction, window? })` | Move into group |
| `move({ into_or_create_group = direction, window? })` | Move into or create group |
| `move({ out_of_group, window? })` | Move out of group |
| `swap({ direction })` | Swap in direction |
| `swap({ target })` | Swap with specific window |
| `swap({ next })` / `swap({ prev })` | Swap with next/prev |
| `center({ window? })` | Center on screen |
| `cycle_next({ next?, tiled?, floating?, window? })` | Focus next window |
| `tag({ tag, window? })` | Tag a window |
| `clear_tags({ window? })` | Clear all tags |
| `toggle_swallow()` | Toggle swallowed windows |
| `pin({ action?, window? })` | Pin window |
| `alter_zorder({ mode, window? })` | Z-order: "top" or "bottom" |
| `set_prop({ prop, value, window? })` | Set window property |
| `deny_from_group({ action? })` | Deny group entry |
| `drag()` | Interactive drag (mouse binds) |
| `resize()` | Interactive resize (mouse binds) |
| `resize({ keep_aspect_ratio })` | Resize keeping aspect ratio |
| `resize({ x, y, relative?, window? })` | Resize by/to pixels |

### Workspace (`hl.dsp.workspace.`)
| Method | Description |
|--------|-------------|
| `rename({ workspace, name? })` | Rename workspace |
| `move({ workspace?, monitor })` | Move workspace to monitor |
| `swap_monitors({ monitor1, monitor2 })` | Swap monitors' workspaces |
| `toggle_special(special_name)` | Toggle scratchpad by name |

### Group (`hl.dsp.group.`)
| Method | Description |
|--------|-------------|
| `toggle({ window? })` | Toggle group |
| `next({ window? })` / `prev({ window? })` | Switch window in group |
| `active({ index, window? })` | Switch to indexed window |
| `move_window({ forward?, window? })` | Reorder in group |
| `lock({ action?, window? })` | Lock group |
| `lock_active({ action? })` | Lock active group |

### Cursor (`hl.dsp.cursor.`)
| Method | Description |
|--------|-------------|
| `move_to_corner({ corner, window? })` | Cursor to corner (0-3) |
| `move({ x, y })` | Cursor to coords |

## hl.animation() / hl.curve()

### Curve types
```lua
-- Bezier
hl.curve("name", { type = "bezier", points = { {x1, y1}, {x2, y2} } })

-- Spring (for bouncy animations)
hl.curve("name", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })
```

### Animation leafs (all from official example)
| Leaf | What it animates |
|------|-----------------|
| `global` | Global speed multiplier |
| `windows` | Window state transitions |
| `windowsIn` | Window opening |
| `windowsOut` | Window closing |
| `fade` | Opacity |
| `fadeIn` | Fade in |
| `fadeOut` | Fade out |
| `border` | Border color |
| `layers` | Layer surfaces |
| `layersIn` | Layer opening |
| `layersOut` | Layer closing |
| `fadeLayersIn` | Layer fade in |
| `fadeLayersOut` | Layer fade out |
| `workspaces` | Workspace switching |
| `workspacesIn` | Workspace open |
| `workspacesOut` | Workspace close |
| `zoomFactor` | Zoom changes |

Supports `spring` or `bezier` as curve source. Style can be `"popin 87%"`, `"fade"`, or omitted.

## hl.on()

Event handlers:
```lua
hl.on("hyprland.start", function() ... end)
hl.on("hyprland.exit", function() ... end)
hl.on("window.open", function(window) ... end)
hl.on("window.close", function(window) ... end)
hl.on("workspace", function(ws) ... end)
hl.on("monitor.add", function(mon) ... end)
hl.on("monitor.remove", function(mon) ... end)
```

## hl.window_rule()

```lua
local r = hl.window_rule({
    name  = "rule-name",          -- optional ID
    match = {
        class      = "kitty",     -- window class (regex)
        title      = ".*",        -- window title (regex)
        xwayland   = true,
        float      = false,
        fullscreen = false,
        pin        = false,
        workspace  = "name:Web",  -- match by workspace
    },
    workspace   = "3",            -- send to workspace
    float       = true,           -- make floating
    no_focus    = true,           -- don't focus
    size        = {800, 600},    -- set size
    opacity     = 0.9,           -- override opacity
    move        = "20 monitor_h-120", -- positioning
    suppress_event = "maximize",  -- ignore maximize requests
    border_size = 0,
    rounding    = 0,
})
r:set_enabled(false)  -- disable rule at runtime
```

## hl.workspace_rule()

```lua
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]",   gaps_out = 0, gaps_in = 0 })
```

## hl.layer_rule()

```lua
local r = hl.layer_rule({
    name  = "no-anim-overlay",
    match = { namespace = "^my-overlay$" },
    no_anim = true,
    ignore_alpha = false,
    blur = false,
})
r:set_enabled(false)
```

## hl.permission()

Restrict what programs can access certain protocols:
```lua
hl.permission("/usr/bin/grim", "screencopy", "allow")
hl.permission("/usr/libexec/xdg-desktop-portal-hyprland", "screencopy", "allow")
```

Requires Hyprland restart to take effect (security).

## hl.gesture()

```lua
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})
```

## hl.device()

Per-device input configuration:
```lua
hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})
```

## hl.timer()

```lua
hl.timer(function()
    hl.dispatch(hl.dsp.dpms({ action = "disable" }))
end, { timeout = 500, type = "oneshot" })
```

## hl.env()

Set environment variables:
```lua
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
```

## hl.exec_cmd()

Execute a command (equivalent to exec-once in hyprlang):
```lua
hl.exec_cmd("kitty")
hl.exec_cmd("hyprpaper")
```

## hl.dispatch()

Invoke a dispatcher immediately (without a keybind):
```lua
hl.dispatch(hl.dsp.window.close())
```

## Color formats

- **rgba string**: `"rgba(RRGGBBAA)"` e.g. `"rgba(0abdc6ff)"`
- **rgb string**: `"rgb(RRGGBB)"` (no alpha)
- **Hex literal (shadow only)**: `0xee1a1a1a` (0x + AA + RRGGBB)

## Workspace selectors

- ID: `1`, `2`, `3`
- Relative: `+1`, `-3`, `+100`
- Monitor-relative: `m+1`, `m-2`, `m~3`
- Monitor including empty: `r+1`, `r~3`
- Open workspace: `e+1`, `e-10`, `e~2`
- Name: `name:Web`, `name:Anime`
- Previous: `previous`, `previous_per_monitor`
- Empty: `empty`, `emptynm` (next empty on monitor)
- Special: `special`, `special:magic`

## hyprctl reference

```bash
hyprctl reload                    # Reload Lua config
hyprctl monitors                 # List monitors
hyprctl workspaces               # List workspaces
hyprctl clients                  # List windows
hyprctl activewindow             # Get focused window
hyprctl activeworkspace          # Get current workspace
hyprctl binds                    # List all keybinds
hyprctl configerrors             # Show config parse errors
hyprctl dispatch <dispatcher>    # Execute a dispatcher
hyprctl hyprpaper wallpaper ,<path>  # Set wallpaper
hyprctl keyword <option> <value> # Change config option
hyprctl notify <icon> <time> <color> <message>

# Dispatcher examples:
hyprctl dispatch exec kitty
hyprctl dispatch workspace 3
hyprctl dispatch movetoworkspace 5
hyprctl dispatch togglefloating
```

## Config verification

```bash
# Gold standard: Hyprland's built-in validator
Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
# Output: "config ok" or detailed errors

# Check runtime errors
hyprctl configerrors

# List all binds (catches duplicate/unwanted binds)
hyprctl binds | grep "key:"
```
