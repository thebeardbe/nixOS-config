-- Hyprland Lua config — Otherland Network theme
-- vim: set ft=lua:

--------------------
---- MY PROGRAMS ----
--------------------
local terminal    = "kitty"
local fileManager = "kitty -e yazi"
local menu        = "fuzzel"
local mainMod     = "SUPER"

-- Reload-safe binding.
--
-- `hyprctl reload` does nothing under Hyprland's Lua config manager (measured:
-- changing an option and reloading leaves it unchanged), so Super+Shift+R has to
-- re-run this file with `dofile`. Re-running it would stack a duplicate of every
-- binding, because Hyprland keeps an existing bind instead of replacing it, and
-- the first match wins - which is exactly how a fixed bind stayed broken while
-- three copies of it accumulated. Unbinding the combo first makes the re-run
-- idempotent.
local function bind(key, dispatcher, opts)
    hl.unbind(key)
    hl["bind"](key, dispatcher, opts)
end


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
    hl.exec_cmd("bash -c 'sleep 2 && packet'")
    hl.exec_cmd("bash -c 'sleep 1; set-wallpaper /home/thebeardbe/Pictures/Wallpapers/solid-bg.png; goto-workspace 1'")

    -- Autostart programs on all machines (after workspace 1 is ready)
    hl.exec_cmd("kitty")                                           -- workspace 1
    hl.exec_cmd("bash -c 'sleep 3 && kitty --class yazi -e yazi'")  -- workspace 3 (via window rule)
    hl.exec_cmd("bash -c 'sleep 4 && kitty --class btop -e btop'")  -- workspace 10 (via window rule)
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
hl.env("HOME", "/home/thebeardbe")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- NVIDIA hardware acceleration
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")


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

    -- Dwindle splits are NOT permanent by default: the direction is recomputed
    -- from the parent node's W/H ratio (W > H -> side-by-side), which means an
    -- ultrawide always splits side-by-side, and `togglesplit` (Super+J) refuses
    -- to work at all. preserve_split makes a split stick until it is changed
    -- explicitly, which is what gives Super+J real effect.
    dwindle = {
        preserve_split = true,
    },

    decoration = {
        rounding          = 10,
        active_opacity    = 1.0,
        inactive_opacity  = 0.90,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(1a1a1aee)",
        },

        blur = {
            enabled = true,
            size    = 6,
            passes  = 2,
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
bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
bind(mainMod .. " + C", hl.dsp.window.close())
bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprctl dispatch 'hl.dsp.exit()'"))
bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
-- Launcher: fuzzel. wofi (drun) was removed: it was slower to appear, and the
-- fuzzel bind that used to sit on Super+Shift+Space now lives on Super+Space.
bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
bind(mainMod .. " + P", hl.dsp.window.pseudo())
-- togglesplit via hyprctl, not hl.dsp.layout(...): binding the Lua layout
-- dispatcher registers a __lua dispatcher that never reaches the dwindle
-- layout (silent no-op, no error in the journal), while the identical message
-- sent through `hyprctl dispatch` works. Requires dwindle.preserve_split.
bind(mainMod .. " + J", hl.dsp.exec_cmd([[hyprctl dispatch 'hl.dsp.layout("togglesplit")']]))
bind(mainMod .. " + F", hl.dsp.window.fullscreen())

-- Window switching: hyprshell was removed. Its overview opened on the Super
-- key, so it kept popping up whenever Super was pressed. Window switching is
-- Super + arrows (movefocus) and Super + 1..0 (workspaces); no Alt+Tab is bound.

-- Menu key → send Super key to Moonlight for remote streaming
-- Uses wtype to inject a real key event via virtual-keyboard protocol
-- (send_shortcut sends synthetic events that Moonlight ignores)
-- wtype uses 'logo' for the Super/Windows key
bind("Menu", hl.dsp.exec_cmd("wtype -M logo -m logo"))

-- Move focus (Vim-style with arrow keys)
bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch to workspace (Super + N) — also sets per-workspace wallpaper
-- goto-workspace script uses Lua-compatible hyprctl dispatch syntax
for i = 1, 9 do
    bind(mainMod .. " + " .. i, hl.dsp.exec_cmd("goto-workspace " .. i))
end
bind(mainMod .. " + 0", hl.dsp.exec_cmd("goto-workspace 10"))

-- Move window to workspace (Super + Shift + N)
for i = 1, 9 do
    bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- Screenshots
bind("Print",          hl.dsp.exec_cmd("hyprshot -m output"))
bind(mainMod .. " + Print", hl.dsp.exec_cmd("hyprshot -m window"))
bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprshot -m region"))  -- select area
bind(mainMod .. " + CTRL + P",  hl.dsp.exec_cmd("hyprshot -m window"))   -- active window
bind(mainMod .. " + ALT + P",   hl.dsp.exec_cmd("hyprshot -m output"))   -- full screen

-- Volume control (repeating for smooth adjustment)
bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5"), { repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5"), { repeating = true })
bind("XF86AudioMute",        hl.dsp.exec_cmd("pamixer -t"))

-- Power button
bind("XF86PowerOff", hl.dsp.exec_cmd("wlogout"))

-- Brightness control (repeating for smooth adjustment)
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set 5%+"), { repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true })

-- Lock screen on demand (idle locking and, on foxyNix only, idle blanking come
-- from hypridle listeners; theConstruct has no idle dpms-off listener)
bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Pick wallpaper (Super + Shift + W)
bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("pick-wallpaper"))

-- Reload config (Super + Shift + R)
-- `hyprctl reload` is a no-op under the Lua config manager, so re-run the file.
-- Every binding goes through the `bind()` helper above, which unbinds first, so
-- repeated reloads do not stack duplicates.
bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd([[hyprctl eval 'dofile(os.getenv("HOME") .. "/.config/hypr/hyprland.lua")']]))

-- Mouse bindings: move/resize with Super + drag
bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Resize mode: Super + Shift + S enters the resize submap, arrows resize,
-- Shift+arrows move the window, Escape exits.
-- Factory function creates a fresh dispatcher table each call (required for repeating)
local function resizeWindow(x, y)
  return function()
    hl.dispatch(hl.dsp.window.resize({ x = x, y = y, relative = true }))
  end
end

local function moveWin(dir)
  return function()
    hl.dispatch(hl.dsp.window.move({ direction = dir }))
  end
end

-- Submap binds also go through the reload-safe helper, otherwise define_submap
-- appends nine more copies on every reload (measured: 10 -> 19 -> 28 -> 37).
-- The catch: unbinding a combo from inside define_submap also removes the
-- global bind of the same name, and the submap binds its own exit on
-- Super+Shift+S. So the global entry bind is registered AFTER the submap, which
-- restores it; the order is what makes both sides idempotent.
hl.define_submap("resize", function()
  bind("left",  resizeWindow(-30, 0),  { repeating = true })
  bind("right", resizeWindow(30, 0),   { repeating = true })
  bind("up",    resizeWindow(0, -30),  { repeating = true })
  bind("down",  resizeWindow(0, 30),   { repeating = true })
  bind("SHIFT + left",  moveWin("l"), { repeating = true })
  bind("SHIFT + right", moveWin("r"), { repeating = true })
  bind("SHIFT + up",    moveWin("u"), { repeating = true })
  bind("SHIFT + down",  moveWin("d"), { repeating = true })
  bind("escape", hl.dsp.submap("reset"))
  -- No Super+Shift+S exit here on purpose: hl.unbind ignores the submap context,
  -- so binding the same combo inside the submap and globally makes the two
  -- remove each other on every reload. Escape exits; Super+Shift+S re-enters.
end)

-- Registered after the submap on purpose (see above).
bind(mainMod .. " + SHIFT + S", hl.dsp.submap("resize"))


----------------------------
---- WINDOW RULES ----
----------------------------
-- Autostart workspace assignments
hl.window_rule({ match = { class = "yazi" }, workspace = "3" })
hl.window_rule({ match = { class = "btop" }, workspace = "10" })

-- Center floating windows
hl.window_rule({ match = { class = "Enpass" }, center = true })
hl.window_rule({ match = { class = "steam" }, center = true })
hl.window_rule({ match = { class = "org.remmina.Remmina" }, center = true })  -- common RDP client

-- Firefox: always 100% opaque (ignore global inactive_opacity)
hl.window_rule({ match = { class = "firefox" }, opacity = 1.0 })

-- Pin Steam's in-game overlay / friend list popups
hl.window_rule({
    name  = "steam-overlay",
    match = { class = "^steam$", float = true },
    center = true,
})

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



