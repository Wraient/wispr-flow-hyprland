# Wispr Flow on Hyprland (seamless)

This project packages the setup that makes **Wispr Flow** work cleanly on **Arch + Hyprland** with:

- Transparent Status HUD at the **bottom** of the **focused** monitor/workspace  
- **Esc** starts push-to-talk (as F20)  
- **Caps Lock key** acts as **Escape** (cancel / normal Esc; never Caps Lock)  
- **No sticky modifiers** (avoid Ctrl/Win/Alt PTT)  
- **No cursor warping**  
- Hub/main window **tiled** when opened; auto-closed only once at Flow startup (tray still works)  
- Optional: hide Wispr from **Dank Material Shell** dock  

Tested with Hyprland **0.55** (Lua config), Wispr Flow **1.6.x**, DMS shell.

---

## Why Hyprland XKB alone is not enough

Wispr’s Linux helper reads **raw `EV_KEY` events** from `/dev/input`.

Hyprland `input.kb_file` / XKB only remaps keys for normal Wayland clients.  
It **never** reaches the helper, so:

| What you set in Hyprland | What Wispr helper still saw |
|---|---|
| Esc → F20 | Esc (`27`) |

**Fix:** grab real keyboards in userspace and emit remapped keys on a virtual device **before** Wispr sees them (`wispr-key-remap`).

```
Physical Esc  --grab-->  wispr-key-remap  --F20-->  Hyprland + Wispr helper
Physical Caps --grab-->  wispr-key-remap  --Esc-->  Hyprland + Wispr helper
```

---

## Layout

```
wispr-flow-hyprland/
├── README.md
├── install.sh
├── uninstall.sh
├── scripts/
│   ├── wispr-key-remap.py          # Esc→F20, Caps→Esc (libevdev + uinput)
│   ├── wispr-set-caps-ptt.sh       # Force config.json shortcuts
│   ├── wispr-status-dock.sh        # Bottom dock via hyprctl only
│   ├── wispr-close-hub.sh          # Close Hub window; keep tray/process
│   ├── wispr-hide-from-dms-dock.sh # Patch DMS dock to hide Wispr
│   └── wispr-cliphist-cleanup.sh   # Optional clipboard cleanup
├── systemd/
│   ├── wispr-key-remap.service
│   ├── wispr-flow.service
│   ├── wispr-status-dock.service
│   └── wispr-cliphist-cleanup.service
├── hypr/
│   ├── windowrules-wispr.lua       # Status HUD + Hub rules
│   └── hyprland-wispr-snippets.lua # no_warps, no kb_file, dms-local note
├── xkb/
│   └── wispr.xkb                   # Reference only (do not use with remapper)
└── dms-patches/
    └── README.md                   # How dock hiding works
```

---

## Prerequisites

- Hyprland (Lua config recommended; snippets target 0.55+)
- Wispr Flow installed (default path used by unit):
  - `/opt/wispr-flow-appimage/usr/lib/wispr-flow/wispr-flow`
- User in `input` group (and ACL/write on `/dev/uinput` as needed)
- Packages: `python-libevdev`, `socat` (for dock event socket), `hyprctl`
- Optional: Dank Material Shell (`dms-shell`) for dock hide
- Optional: `ydotool` is **not** required for this setup

```bash
# Arch examples
sudo pacman -S python-libevdev socat
# ensure input group
groups | tr ' ' '\n' | grep -x input || echo "add user to input group, re-login"
```

---

## Quick install

```bash
cd wispr-flow-hyprland
./install.sh
hyprctl reload   # if Hyprland already running
```

Then:

1. Hold **Esc** → Wispr should listen (PTT).  
2. Press **Caps Lock key** → Escape / cancel.  
3. Status pill at bottom of focused workspace.  
4. Hub should not stay open; open it from tray when needed.

---

## What each piece does

### 1. `wispr-key-remap.service` (critical)

- Grabs real keyboards (`Compx Hydra`, laptop AT keyboard, etc.)
- Emits on virtual device `wispr-key-remap`
- Map:
  - `KEY_ESC` → `KEY_F20`
  - `KEY_CAPSLOCK` → `KEY_ESC`
- Skips virtual devices (ydotool, vicinae, Wispr helper)
- **Never** moves the mouse

Requires: `python-libevdev`, access to `/dev/input/event*` and `/dev/uinput`.

### 2. Wispr shortcuts (`wispr-set-caps-ptt.sh`)

Writes into `~/.config/Wispr Flow/config.json`:

```json
"131": "ptt",      // F20
"27": "dismiss"    // Escape
```

Flow often overwrites shortcuts on start/exit; the Flow unit re-runs this script before/after start.

### 3. `wispr-flow.service`

- Starts Flow after the remapper
- Re-applies shortcuts
- Keeps process running for tray + Status

Edit `ExecStart=` if your binary path differs.

### 4. Window rules (`hypr/windowrules-wispr.lua`)

Status:

- float, bottom-ish placement  
- `opacity 0.92`, `no_shadow`, `no_focus` (click-through style)  
- no blur/anim/border  

Hub (main settings app):

- **tiled** (`float = false`) when you open it  
- **not** continuously auto-closed (you can open it from launcher/tray)  
- closed **once** shortly after Flow autostart via `wispr-close-hub-once.sh` so boot stays clean  
- open anytime with `wispr-open-hub.sh` / desktop entry **Wispr Flow Hub**  

### 5. `wispr-status-dock.service`

Event-driven (Hyprland socket2):

- `workspace`, `openwindow`, `focusedmon`, `movewindow`
- Moves Status to bottom center of **focused monitor** and active workspace  
- **hyprctl only** — no ydotool / no cursor API  

Env: `WISPR_STATUS_BOTTOM_GAP` (default `36`).

### 6. Cursor no warps

```lua
hl.config({
    cursor = {
        no_warps = true,
        warp_on_change_workspace = 0,
        warp_on_toggle_special = 0,
    },
})
```

### 7. Dank dock hide (optional)

`install.sh` runs `wispr-hide-from-dms-dock.sh` which:

- Builds `~/.config/quickshell/dms-local` from system DMS  
- Filters `wispr-flow` / Status / Hub out of dock + running-apps widgets  
- Autostart uses:
  ```bash
  qs -p ~/.config/quickshell/dms-local -n -d
  ```
  instead of `dms run`

After DMS package upgrades:

```bash
~/.config/hypr/scripts/wispr-hide-from-dms-dock.sh
qs -p ~/.config/quickshell/dms-local -n -d
```

---

## Key bindings (end result)

| Physical key | Emitted | Effect |
|---|---|---|
| **Esc** | F20 | Wispr PTT (hold to talk) |
| **Caps Lock** | Escape | Cancel / normal Esc |

Do **not** bind PTT to Ctrl/Win/Alt combos on Linux helper — those sticky-modifier bugs are why this setup uses a single non-modifier key.

---

## Manual checklist (if not using install.sh)

1. Copy `scripts/*` → `~/.config/hypr/scripts/` and `chmod +x`  
2. Copy `systemd/*` → `~/.config/systemd/user/`  
3. Merge `hypr/windowrules-wispr.lua` into your window rules  
4. Merge cursor / autostart notes from `hypr/hyprland-wispr-snippets.lua`  
5. **Do not** enable Esc→F20 via `input.kb_file` while the remapper runs (double-map turns Caps into F20)  
6. `systemctl --user daemon-reload`  
7. `systemctl --user enable --now wispr-key-remap wispr-status-dock wispr-flow`  
8. Optional: run `wispr-hide-from-dms-dock.sh`  

---

## Verify

```bash
# services
systemctl --user is-active wispr-key-remap wispr-flow wispr-status-dock

# remapper log
tail -20 "${XDG_RUNTIME_DIR:-/run/user/$UID}/wispr-key-remap.log"

# helper should open the virtual keyboard (name wispr-key-remap)
# hold Esc once, then:
rg 'keycodes: f20|Ptt action|startDictation' ~/.config/Wispr\ Flow/logs/main.log | tail

# windows
hyprctl clients -j | jq '.[] | select(.class=="wispr-flow") | {title,at,workspace}'
```

Expect log lines like:

```text
Handling action from keycodes: f20, curKey: 131
Ptt action down
startDictation ... listening
```

If you still see `keycodes: esc` for physical Esc, the remapper is not grabbing that keyboard.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Esc does nothing for Wispr | `systemctl --user restart wispr-key-remap wispr-flow`; check remapper log for `grabbed` |
| Caps starts Wispr | You still have XKB Esc→F20 (`kb_file`) **and** remapper; remove `kb_file` |
| Sticky Super/Ctrl | Stop using modifier PTT combos; stick to Esc→F20 |
| Mouse jumps | Ensure `cursor.no_warps = true`; dock script must not call cursor APIs |
| Hub keeps reopening | `wispr-status-dock` should call `wispr-close-hub.sh`; check that unit is active |
| Wispr icon still in DMS dock | Re-run hide script; ensure autostart uses `dms-local`, not stock `dms run` |
| Shortcuts reset | Flow overwrites config; unit re-applies `wispr-set-caps-ptt.sh` — run it manually after UI changes |
| No uinput / grab fails | User must be in `input` group; check `/dev/uinput` permissions/ACL |

TTY switch (Ctrl+Alt+F2) was only a recovery for stuck modifiers from **old** combos; not needed with Esc PTT.

---

## Uninstall

```bash
./uninstall.sh
```

Then remove scripts/units and revert window rules / `dms-local` autostart if you want a full cleanup.

---

## Design notes / things we deliberately avoided

- **No ydotool for docking or mouse** (pointer warps / focus weirdness)  
- **No keyd-only solution in this package** (works, but needs root `/etc/keyd`; remapper is user-level)  
- **No Hyprland-only XKB remap for Wispr PTT** (helper ignores it)  
- **No modifier-chord PTT** (Linux helper sticky-key issues)  

---

## License / ownership

Config and scripts for personal Hyprland desktop integration with Wispr Flow.  
Wispr Flow itself is third-party software; this repo only contains integration glue.
