# Patched wispr-flow-linux-helper

Upstream: https://github.com/wispr-flow-linux/helper

## Change

On the **capture path only** (physical keys → Wispr app):

| Physical key | Linux KEY_* | Reported to Flow as |
|---|---|---|
| Esc | `KEY_ESC` (1) | **F20** (VK 131) → PTT |
| Caps Lock | `KEY_CAPSLOCK` (58) | **Escape** (VK 27) → dismiss / Esc |

Injection (Flow → apps via uinput) is unchanged.

## Why not Hyprland XKB alone?

Flow’s helper reads `/dev/input` raw EV_KEY and ignores compositor XKB.
Remapping must happen **inside the helper** (this patch) or with a grab/remap
device (the old workaround we removed).

## Build

```bash
git clone https://github.com/wispr-flow-linux/helper.git
cd helper
git apply /path/to/esc-caps-remap.patch
cargo build --release
cp target/release/wispr-flow-linux-helper ~/.local/lib/wispr-flow/
```

Or use the prebuilt `bin/wispr-flow-linux-helper` from this repo.

## Launch

`scripts/wispr-flow-launch.sh` uses `bwrap` to overlay the patched helper over
the stock path inside the AppImage without root.
