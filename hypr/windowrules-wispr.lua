-- --- Wispr Flow ---
-- Transparent Status HUD, bottom placement on map.
-- Workspace following is done by hyprctl script (no ydotool).
hl.window_rule({
    name = "wispr-status",
    match = { class = "^(wispr-flow)$", title = "^(Status)$" },
    float = true,
    move = "monitor_w/2-220 monitor_h-356",
    opacity = "0.92 0.92",
    no_shadow = true,
    no_focus = true,
    no_follow_mouse = true,
    no_initial_focus = true,
    focus_on_activate = false,
    no_blur = true,
    no_anim = true,
    no_dim = true,
    border_size = 0,
    rounding = 0,
    decorate = false,
    suppress_event = "activate activatefocus maximize fullscreen",
})
hl.window_rule({
    name = "wispr-status-initial",
    match = { class = "^(wispr-flow)$", initial_title = "^(Flow Status Indicator)$" },
    float = true,
    move = "monitor_w/2-220 monitor_h-356",
    opacity = "0.92 0.92",
    no_shadow = true,
    no_focus = true,
    no_follow_mouse = true,
    no_initial_focus = true,
    focus_on_activate = false,
    no_blur = true,
    no_anim = true,
    no_dim = true,
    border_size = 0,
    rounding = 0,
    decorate = false,
    suppress_event = "activate activatefocus maximize fullscreen",
})
-- Hub/main settings window: tiled (not floating). Status HUD stays floating.
-- Startup-only auto-close is handled by wispr-close-hub-once.sh (not continuous).
hl.window_rule({
    name = "wispr-hub",
    match = { class = "^(wispr-flow)$", title = "^(Hub)$" },
    float = false,
})
hl.window_rule({
    name = "wispr-hub-initial",
    match = { class = "^(wispr-flow)$", initial_title = "^(Hub)$" },
    float = false,
})
