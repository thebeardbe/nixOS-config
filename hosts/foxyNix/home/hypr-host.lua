-- foxyNix: Laptop single monitor + touchpad

hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

-- Touchpad settings (laptop built-in)
hl.config({
    input = {
        touchpad = {
            natural_scroll        = true,
            tap_to_click          = true,
            disable_while_typing  = true,
        },
    },
})

-- Signal on workspace 6
hl.window_rule({ match = { class = "Signal|signal-desktop" }, rule_extra = "workspace 6" })

hl.on("hyprland.start", function()
    hl.exec_cmd("bash -c 'sleep 6 && signal-desktop &'")
end)
