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
-- Hub/main app: do not park on special workspace. Close it; tray keeps Flow alive.
hl.window_rule({
    name = "wispr-hub",
    match = { class = "^(wispr-flow)$", title = "^(Hub)$" },
    float = true,
    no_initial_focus = true,
    focus_on_activate = false,
    suppress_event = "activate activatefocus",
})
hl.window_rule({
    name = "wispr-hub-initial",
    match = { class = "^(wispr-flow)$", initial_title = "^(Hub)$" },
    float = true,
    no_initial_focus = true,
    focus_on_activate = false,
    suppress_event = "activate activatefocus",
})
