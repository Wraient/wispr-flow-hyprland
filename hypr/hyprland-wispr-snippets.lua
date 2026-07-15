-- Wispr Flow related Hyprland snippets (Lua config / Hyprland 0.55+)
-- Merge into your hyprland.lua as appropriate.

-- Autostart Dank Material Shell with local overlay that hides Wispr from the dock.
-- Replace plain `dms run` with:
--   hl.exec_cmd("qs -p " .. os.getenv("HOME") .. "/.config/quickshell/dms-local -n -d")

-- INPUT: do NOT set input.kb_file for Esc/Caps remap.
-- Wispr's Linux helper reads raw EV_KEY; Hyprland XKB never reaches it.
-- Device-level remap is handled by wispr-key-remap.service instead.
hl.config({
    input = {
        -- Device-level remap (wispr-key-remap.service) handles Esc->F20 and Caps->Esc
        -- for Wispr's raw EV_KEY helper. Do NOT also map via kb_file or Caps becomes F20.
        kb_layout = "us",
        -- kb_file = intentionally unset
    },
})

-- Never warp cursor on window/workspace moves (critical for Status HUD docking)
hl.config({
    cursor = {
        no_warps = true,
        warp_on_change_workspace = 0,
        warp_on_toggle_special = 0,
    },
})
