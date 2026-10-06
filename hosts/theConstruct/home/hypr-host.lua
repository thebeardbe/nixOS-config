-- theConstruct: Dual monitor setup
hl.monitor({
    output   = "DP-2",
    mode     = "1920x1080@165",
    position = "0x0",
    scale    = "1",
})
hl.monitor({
    output   = "DP-1",
    mode     = "3440x1440@60",
    position = "-760x-1440",
    scale    = "1",
})

-- X11 (XWayland) primary monitor.
-- DP-1 sits at negative coordinates, so XWayland places it at X11 +0+0 and
-- Wine/Proton then treats the ultrawide as the primary display. Games without a
-- display selector fullscreen on the ultrawide, and when launched on a DP-2
-- workspace the window and the game disagree about the resolution, which makes
-- clicking offset. Setting DP-2 as the XRandR primary fixes that for every game
-- at once, with no wrapper in the render path. XWayland may not be up when this
-- runs, so retry briefly.
-- Per-game override for a title that should use the ultrawide instead, as a
-- Steam launch option:   xrandr --output DP-1 --primary ; %command%
hl.on("hyprland.start", function()
    hl.exec_cmd("bash -c 'for _ in 1 2 3 4 5; do xrandr --output DP-2 --primary && break; sleep 2; done'")
end)

-- Workspaces 1-6 on DP-2 (main gaming), 7-10 on DP-1 (ultrawide)
for i = 1, 6 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-2", persistent = true })
end
for i = 7, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1", persistent = true })
end

-- Window rules: signal and firefox on workspace 7
hl.window_rule({ match = { class = "Signal|signal-desktop" }, workspace = "7" })
hl.window_rule({ match = { class = "firefox|Firefox" },       workspace = "7" })

-- Autostart: signal + firefox on workspace 7 with 1/3-2/3 split
hl.on("hyprland.start", function()
    hl.exec_cmd("bash -c 'sleep 5 && hyprctl dispatch workspace 7 && signal-desktop &'")
    hl.exec_cmd("bash -c 'sleep 7 && hyprctl dispatch workspace 7 && firefox &'")
    hl.exec_cmd("bash -c 'sleep 12 && hyprctl dispatch workspace 7 && hyprctl dispatch layoutmsg setsplitratio 0.33'")
end)
