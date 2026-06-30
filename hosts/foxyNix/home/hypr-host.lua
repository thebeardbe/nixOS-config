-- foxyNix: Laptop single monitor + touchpad

hl.monitor({
    output   = "eDP-1",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

-- Touchpad settings (laptop built-in)
-- Note: Lua API uses different key names than hyprlang
hl.config({
    input = {
        touchpad = {
            natural_scroll        = true,
            tap_to_click          = true,
            disable_while_typing  = true,
        },
    },
})
