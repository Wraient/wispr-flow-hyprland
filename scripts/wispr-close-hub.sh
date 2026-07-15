#!/usr/bin/env bash
# Close Wispr Flow Hub/main window only. Keep process, Status HUD, and tray.
set -euo pipefail
python3 - <<'PY'
import json
import subprocess

clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
closed = 0
for c in clients:
    if c.get("class") != "wispr-flow":
        continue
    title = c.get("title") or ""
    initial = c.get("initialTitle") or ""
    if title in ("Status", "Flow Status Indicator"):
        continue
    if title != "Hub" and initial != "Hub":
        continue
    addr = c["address"]
    r = subprocess.run(
        [
            "hyprctl",
            "eval",
            f'hl.dispatch(hl.dsp.window.close({{ window = "address:{addr}" }}))',
        ],
        capture_output=True,
        text=True,
    )
    print(f"closed Hub {addr} rc={r.returncode}")
    closed += 1
if closed == 0:
    print("no Hub window")
PY
