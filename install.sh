#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_SCRIPTS="$CFG/hypr/scripts"
SYSTEMD_USER="$CFG/systemd/user"
LIB="$HOME/.local/lib/wispr-flow"

echo "==> Scripts"
mkdir -p "$HYPR_SCRIPTS" "$SYSTEMD_USER" "$LIB" "$CFG/xkb" "$CFG/hypr"
install -m 0755 "$ROOT"/scripts/*.sh "$HYPR_SCRIPTS/" 2>/dev/null || true
install -m 0755 "$ROOT/bin/wispr-flow-linux-helper" "$LIB/wispr-flow-linux-helper"

echo "==> Units"
install -m 0644 "$ROOT"/systemd/wispr-*.service "$SYSTEMD_USER/" 2>/dev/null || true
# neutralize old remapper if present
systemctl --user disable --now wispr-key-remap.service 2>/dev/null || true

echo "==> XKB + window rules"
install -m 0644 "$ROOT/xkb/wispr.xkb" "$CFG/xkb/wispr.xkb"
if [[ -f "$CFG/hypr/windowrules.lua" ]] && ! grep -q 'wispr-status' "$CFG/hypr/windowrules.lua"; then
  { echo; cat "$ROOT/hypr/windowrules-wispr.lua"; } >> "$CFG/hypr/windowrules.lua"
fi
# ensure flow unit points at launch script for this user
sed -i "s|/home/wraient|$HOME|g" "$SYSTEMD_USER/wispr-flow.service" "$HYPR_SCRIPTS"/*.sh 2>/dev/null || true

if [[ -f "$CFG/hypr/hyprland.lua" ]]; then
  python3 - <<'PY'
from pathlib import Path
import os
p=Path(os.path.expanduser("~/.config/hypr/hyprland.lua"))
t=p.read_text(); home=str(Path.home())
if "wispr.xkb" not in t:
    t=t.replace('input = {\n        kb_layout = "us",',
                f'input = {{\n        kb_file = "{home}/.config/xkb/wispr.xkb",\n        kb_layout = "us",',1)
if "no_warps" not in t:
    t += '\nhl.config({ cursor = { no_warps = true, warp_on_change_workspace = 0, warp_on_toggle_special = 0 } })\n'
p.write_text(t)
print("hyprland.lua adjusted")
PY
fi

if [[ -d /usr/share/quickshell/dms ]]; then
  "$HYPR_SCRIPTS/wispr-hide-from-dms-dock.sh" || true
fi

systemctl --user daemon-reload
systemctl --user enable --now wispr-status-dock.service
systemctl --user enable --now wispr-cliphist-cleanup.service 2>/dev/null || true
if [[ -x /opt/wispr-flow-appimage/usr/lib/wispr-flow/wispr-flow ]]; then
  systemctl --user enable --now wispr-flow.service
else
  echo "WARN: install Wispr Flow AppImage to /opt/wispr-flow-appimage first"
fi
"$HYPR_SCRIPTS/wispr-set-caps-ptt.sh" || true
echo "Done. Hold Esc to talk; Caps = Escape. Do not re-enable wispr-key-remap."
