-- Caps -> Escape, Esc -> F20 for normal apps (compositor path)
hl.config({
    input = {
        kb_file = os.getenv("HOME") .. "/.config/xkb/wispr.xkb",
        kb_layout = "us",
    },
})

-- Never warp cursor (Status HUD docking)
hl.config({
    cursor = {
        no_warps = true,
        warp_on_change_workspace = 0,
        warp_on_toggle_special = 0,
    },
})

-- Optional DMS with Wispr hidden from dock:
-- hl.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/quickshell/dms-local -n -d")
