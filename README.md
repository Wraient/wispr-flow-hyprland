# Wispr Flow on Hyprland

Seamless Wispr Flow integration for Arch + Hyprland:

| Physical key | Result |
|---|---|
| **Esc** | Start Wispr PTT (hold to talk) |
| **Caps Lock** | Escape (apps + Wispr cancel). Never Caps Lock |

No grab/remap daemon. No sticky-modifier workarounds as the primary path.

## Architecture (the correct way)

```
Physical keyboard
   │
   ├─► Hyprland XKB (kb_file) ──► normal apps (Caps=Esc, Esc=F20)
   │
   └─► patched wispr-flow-linux-helper (raw EV_KEY)
            remap Esc→F20, Caps→Esc ──► Wispr Electron Keyboard Service
```

Wispr’s Linux helper **must** see remapped codes because it reads `/dev/input`
directly and **ignores** compositor XKB. The clean fix is patching the helper’s
capture path (upstream is open: [wispr-flow-linux/helper](https://github.com/wispr-flow-linux/helper)).

### What we removed

- `wispr-key-remap` grab/uinput proxy (caused complexity / sticky-key races)
- Continuous Hub killing
- Modifier-chord PTT

## Quick install

Requirements: Hyprland, Wispr Flow AppImage under `/opt/wispr-flow-appimage`,
`bubblewrap` (`bwrap`), `python-libevdev` optional (only for emergency unstick),
`socat` for dock events.

```bash
./install.sh
hyprctl reload
```

Then hold **Esc** to dictate; **Caps** for Escape/cancel.

## Layout

```
bin/wispr-flow-linux-helper     # prebuilt patched helper
helper-patch/                  # source patch + README to rebuild
scripts/
  wispr-flow-launch.sh         # bwrap overlay + start Flow
  wispr-set-caps-ptt.sh        # force "131"=ptt, "27"=dismiss
  wispr-status-dock.sh         # bottom Status HUD (hyprctl only)
  wispr-close-hub-once.sh      # close Hub once after autostart
  wispr-open-hub.sh            # open Hub tiled on demand
  wispr-hide-from-dms-dock.sh  # optional DMS dock hide
  wispr-unstick-mods.sh        # emergency only
systemd/wispr-flow.service     # uses launch.sh
hypr/windowrules-wispr.lua
xkb/wispr.xkb
```

## Rebuild helper from source

```bash
git clone https://github.com/wispr-flow-linux/helper.git
cd helper
git apply /path/to/this/repo/helper-patch/esc-caps-remap.patch
cargo build --release
install -Dm755 target/release/wispr-flow-linux-helper ~/.local/lib/wispr-flow/wispr-flow-linux-helper
systemctl --user restart wispr-flow.service
```

## Verify

```bash
systemctl --user is-active wispr-flow          # active
systemctl --user is-active wispr-key-remap     # inactive (must stay off)
hyprctl getoption input:kb_file                # .../xkb/wispr.xkb

# Hold Esc, then:
rg 'keycodes: f20|Ptt action' ~/.config/Wispr\ Flow/logs/main.log | tail
```

## Hub window

- **Tiled** when opened  
- Auto-closed **once** after Flow autostart only  
- Open anytime: desktop entry **Wispr Flow Hub** or `wispr-open-hub.sh`

## License

Integration glue for personal use. Wispr Flow is proprietary.  
Helper patch is based on the Unlicense `wispr-flow-linux/helper` project.
