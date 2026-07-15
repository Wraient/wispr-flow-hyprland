#!/usr/bin/env bash
# Install Wispr Flow + Hyprland seamless setup for this user.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYPR_SCRIPTS="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
SYSTEMD_USER="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
XKB_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xkb"

echo "==> Installing scripts to $HYPR_SCRIPTS"
mkdir -p "$HYPR_SCRIPTS" "$SYSTEMD_USER" "$XKB_DIR"
install -m 0755 "$ROOT"/scripts/wispr-*.sh "$HYPR_SCRIPTS/" 2>/dev/null || true
install -m 0755 "$ROOT"/scripts/wispr-*.py "$HYPR_SCRIPTS/" 2>/dev/null || true
# ensure all executable
chmod +x "$HYPR_SCRIPTS"/wispr-*

echo "==> Installing systemd user units"
install -m 0644 "$ROOT"/systemd/wispr-*.service "$SYSTEMD_USER/"
if [[ -d "$ROOT/systemd/wispr-cliphist-cleanup.service.d" ]]; then
  mkdir -p "$SYSTEMD_USER/wispr-cliphist-cleanup.service.d"
  install -m 0644 "$ROOT"/systemd/wispr-cliphist-cleanup.service.d/* \
    "$SYSTEMD_USER/wispr-cliphist-cleanup.service.d/" || true
fi

echo "==> Installing reference XKB map (optional; remapper does not need it)"
install -m 0644 "$ROOT/xkb/wispr.xkb" "$XKB_DIR/wispr.xkb"

echo "==> Window rules / hypr snippets (manual merge required)"
echo "    See: $ROOT/hypr/windowrules-wispr.lua"
echo "    See: $ROOT/hypr/hyprland-wispr-snippets.lua"
if [[ -f "$HYPR_DIR/windowrules.lua" ]]; then
  if ! grep -q 'wispr-status' "$HYPR_DIR/windowrules.lua" 2>/dev/null; then
    echo "    Appending Wispr window rules to $HYPR_DIR/windowrules.lua"
    {
      echo ""
      cat "$ROOT/hypr/windowrules-wispr.lua"
    } >> "$HYPR_DIR/windowrules.lua"
  else
    echo "    windowrules.lua already mentions wispr-status; left unchanged"
  fi
else
  echo "    WARNING: $HYPR_DIR/windowrules.lua not found; copy rules manually"
fi

# Patch hyprland.lua cursor/no kb_file/autostart if present
if [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
  python3 - <<'PY'
from pathlib import Path
import os
p = Path(os.path.expanduser("~/.config/hypr/hyprland.lua"))
text = p.read_text()
changed = False
# ensure no_warps
if "no_warps" not in text:
    text += """
hl.config({
    cursor = {
        no_warps = true,
        warp_on_change_workspace = 0,
        warp_on_toggle_special = 0,
    },
})
"""
    changed = True
# prefer dms-local if dms run present
if 'hl.exec_cmd("dms run")' in text and "dms-local" not in text:
    text = text.replace(
        'hl.exec_cmd("dms run")',
        f'hl.exec_cmd("qs -p {Path.home()}/.config/quickshell/dms-local -n -d")',
        1,
    )
    changed = True
if changed:
    p.write_text(text)
    print("    Updated hyprland.lua (cursor / dms-local autostart)")
else:
    print("    hyprland.lua left mostly unchanged (review hyprland-wispr-snippets.lua)")
PY
fi

echo "==> Applying Dank Material Shell dock hide patch (if DMS installed)"
if [[ -d /usr/share/quickshell/dms ]]; then
  "$HYPR_SCRIPTS/wispr-hide-from-dms-dock.sh" || true
else
  echo "    DMS not found at /usr/share/quickshell/dms; skip dock hide"
fi

echo "==> Enabling user services"
systemctl --user daemon-reload
systemctl --user enable --now wispr-key-remap.service
systemctl --user enable --now wispr-status-dock.service
systemctl --user enable --now wispr-cliphist-cleanup.service || true
# Flow binary path may differ; only enable if binary exists
if [[ -x /opt/wispr-flow-appimage/usr/lib/wispr-flow/wispr-flow ]]; then
  systemctl --user enable --now wispr-flow.service
else
  echo "    WARNING: Wispr binary not at /opt/wispr-flow-appimage/...; edit systemd/wispr-flow.service"
fi

# Force shortcuts
"$HYPR_SCRIPTS/wispr-set-caps-ptt.sh" || true

echo
echo "Done."
echo "Keys: hold Esc = Wispr PTT (F20); Caps Lock key = Escape (cancel)."
echo "Reload Hyprland config if needed: hyprctl reload"
echo "If using DMS dock hide, restart shell:"
echo "  qs -p \"\$HOME/.config/quickshell/dms-local\" -n -d"
