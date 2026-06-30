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

-- Workspaces 1-7 on DP-2 (main gaming), 8-10 on DP-1 (ultrawide)
for i = 1, 7 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-2", persistent = true })
end
for i = 8, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1", persistent = true })
end
