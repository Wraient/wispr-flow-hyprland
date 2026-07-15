#!/usr/bin/env bash
# Open / focus Wispr Flow Hub. Safe with already-running tray instance.
set -euo pipefail

focus_existing_hub() {
  python3 - <<'PY'
import json, subprocess, sys
clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
for c in clients:
    if c.get("class") != "wispr-flow":
        continue
    title = c.get("title") or ""
    initial = c.get("initialTitle") or ""
    if title == "Hub" or initial == "Hub":
        addr = c["address"]
        subprocess.run(
            ["hyprctl", "eval", f'hl.dispatch(hl.dsp.window.focus({{ window = "address:{addr}" }}))'],
            capture_output=True, text=True,
        )
        print(f"focused Hub {addr}")
        sys.exit(0)
sys.exit(1)
PY
}

if focus_existing_hub; then
  exit 0
fi

# Launch / activate existing single-instance app (should map Hub)
if command -v wispr-flow >/dev/null 2>&1; then
  nohup wispr-flow "$@" >/dev/null 2>&1 &
elif [[ -x /opt/wispr-flow-appimage/usr/lib/wispr-flow/wispr-flow ]]; then
  nohup /opt/wispr-flow-appimage/usr/lib/wispr-flow/wispr-flow --no-sandbox --class='Wispr Flow' "$@" >/dev/null 2>&1 &
elif [[ -x /opt/wispr-flow-appimage/AppRun ]]; then
  nohup /opt/wispr-flow-appimage/AppRun "$@" >/dev/null 2>&1 &
else
  echo "Wispr Flow binary not found" >&2
  exit 1
fi

# Wait briefly and focus if Hub appears
for _ in 1 2 3 4 5 6 7 8 9 10; do
  sleep 0.3
  if focus_existing_hub; then
    exit 0
  fi
done
echo "launched Wispr Flow (Hub may open shortly)"
