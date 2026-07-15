#!/usr/bin/env bash
# Force-release stuck keyboard modifiers (Control/Alt/Shift/Super) and PTT keys.
set -euo pipefail
python3 - <<'PY'
import libevdev, time
from libevdev import EV_KEY, EV_SYN, InputEvent

d = libevdev.Device()
d.name = "wispr-mod-unstick"
d.id = {"bustype": 3, "vendor": 0x5653, "product": 0x5553, "version": 1}
mods = [
    EV_KEY.KEY_LEFTCTRL, EV_KEY.KEY_RIGHTCTRL,
    EV_KEY.KEY_LEFTALT, EV_KEY.KEY_RIGHTALT,
    EV_KEY.KEY_LEFTSHIFT, EV_KEY.KEY_RIGHTSHIFT,
    EV_KEY.KEY_LEFTMETA, EV_KEY.KEY_RIGHTMETA,
    EV_KEY.KEY_ESC, EV_KEY.KEY_F20, EV_KEY.KEY_CAPSLOCK,
]
for k in mods:
    d.enable(k)
ui = d.create_uinput_device()
time.sleep(0.05)
for _ in range(3):
    ev = [InputEvent(k, 0) for k in mods] + [InputEvent(EV_SYN.SYN_REPORT, 0)]
    ui.send_events(ev)
    time.sleep(0.03)
print("released modifiers")
PY
