#!/usr/bin/env bash
# Launch Wispr Flow with our Hyprland-aware Linux helper (Esc→F20, Caps→Esc in capture).
set -euo pipefail
HELPER="${WISPR_HELPER_BIN:-$HOME/.local/lib/wispr-flow/wispr-flow-linux-helper}"
STOCK="/opt/wispr-flow-appimage/usr/lib/wispr-flow/resources/Release/wispr-flow-linux-helper"
FLOW="/opt/wispr-flow-appimage/usr/lib/wispr-flow/wispr-flow"

if [[ ! -x "$HELPER" ]]; then
  echo "patched helper missing: $HELPER" >&2
  exit 1
fi
if [[ ! -x "$FLOW" ]]; then
  echo "Wispr Flow missing: $FLOW" >&2
  exit 1
fi

# Overlay only the helper binary so Electron still finds the stock path.
# --dev-bind / / keeps full FS; bind our helper over the stock one.
exec bwrap \
  --bind / / \
  --dev-bind /dev /dev \
  --proc /proc \
  --bind "$HELPER" "$STOCK" \
  --die-with-parent \
  "$FLOW" --no-sandbox --class='Wispr Flow' "$@"
