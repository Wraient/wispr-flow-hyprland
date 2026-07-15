#!/usr/bin/env bash
# Close Hub once shortly after Flow starts so it doesn't steal a workspace.
# Does NOT keep closing Hub later — user can open it from launcher/tray anytime.
set -euo pipefail
sleep "${WISPR_CLOSE_HUB_DELAY:-4}"
exec "${HOME}/.config/hypr/scripts/wispr-close-hub.sh"
