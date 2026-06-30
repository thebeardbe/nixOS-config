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
