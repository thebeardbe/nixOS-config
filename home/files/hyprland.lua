-- Hyprland Lua config — Otherland Network theme
-- vim: set ft=lua:

--------------------
---- MY PROGRAMS ----
--------------------
local terminal    = "kitty"
local fileManager = "kitty -e yazi"
local menu        = "wofi --show drun"
local mainMod     = "SUPER"


------------------
---- MONITORS ----
------------------
-- Default: auto-detect. Override per-host in ~/.config/hypr/host.lua
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})


-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    -- Systemd session activation (replaces home-manager's hyprland.conf exec-once)
    hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE && systemctl --user stop hyprland-session.target && systemctl --user start hyprland-session.target")
    -- User applications
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("hyprshell run -c ~/.config/hyprshell/config.toml")
    hl.exec_cmd("bash -c 'hyprctl hyprpaper \"wallpaper ,/home/thebeardbe/Pictures/Wallpapers/solid-bg.png\" 2>/dev/null; sleep 1 && goto-workspace 1'")
end)

-- Load host-specific overrides (monitors, touchpad, etc.)
-- Each host's default.nix deploys ~/.config/hypr/host.lua
local ok, _ = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/host.lua")
if not ok then
    -- Host file not found, using defaults
end


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("PLAYWRIGHT_BROWSERS_PATH", "/home/thebeardbe/.nix-profile/lib/playwright")
hl.env("HOME", "/home/thebeardbe")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")


-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in       = 5,
        gaps_out      = 10,
        border_size   = 2,
        col = {
            active_border   = { colors = {"rgba(0abdc6ff)"} },
            inactive_border = "rgba(000b1eaa)",
        },
        allow_tearing = false,
        layout        = "dwindle",
    },

    decoration = {
        rounding          = 10,
        active_opacity    = 0.95,
        inactive_opacity  = 0.75,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
            xray    = true,
        },
    },

    misc = {
        disable_watchdog_warning = true,
        force_default_wallpaper  = 0,
        disable_hyprland_logo    = true,
    },
})


---------------
---- INPUT ----
---------------
hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "altgr-intl",
    },
})


---------------------------------
---- ANIMATIONS & CURVES ----
---------------------------------
hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "global",     enabled = true, speed = 1, bezier = "default" })
hl.animation({ leaf = "windows",    enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",     enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade",       enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })


-------------------
---- KEYBINDS ----
-------------------
-- Basic actions
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

-- Window switching: hyprshell registers its own Alt+Tab binds natively via IPC
-- (eval hl.dispatch works because Lua config is active)
-- hyprshell run is started in hl.on("hyprland.start") above

-- Move focus (Vim-style with arrow keys)
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch to workspace (Super + N) — also sets per-workspace wallpaper
-- goto-workspace script uses Lua-compatible hyprctl dispatch syntax
for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.exec_cmd("goto-workspace " .. i))
end
hl.bind(mainMod .. " + 0", hl.dsp.exec_cmd("goto-workspace 10"))

-- Move window to workspace (Super + Shift + N)
for i = 1, 9 do
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Screenshots
hl.bind("Print",          hl.dsp.exec_cmd("hyprshot -m output"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("hyprshot -m window"))

-- Volume control (repeating for smooth adjustment)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5"), { repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pamixer -t"))

-- Power button
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("wlogout"))

-- Brightness control (repeating for smooth adjustment)
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })

-- Lock screen
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Pick wallpaper (Super + Shift + W)
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("pick-wallpaper"))

-- Reload Hyprland config (Super + Shift + R)
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))

-- Mouse bindings: move/resize with Super + drag
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


----------------------------
---- WINDOW RULES ----
----------------------------
-- Fix dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})



