#!/usr/bin/env bash
set -euo pipefail
systemctl --user disable --now wispr-flow.service 2>/dev/null || true
systemctl --user disable --now wispr-key-remap.service 2>/dev/null || true
systemctl --user disable --now wispr-status-dock.service 2>/dev/null || true
systemctl --user disable --now wispr-cliphist-cleanup.service 2>/dev/null || true
echo "Services stopped. Scripts remain in ~/.config/hypr/scripts (remove manually if desired)."
echo "To restore stock DMS: kill local qs and run: dms run"
