#!/usr/bin/env bash
# Place Wispr Status at bottom of the focused monitor's active workspace.
# hyprctl ONLY. Never ydotool / cursor.move.
# Only repositions on workspace/monitor/openwindow events — not a tight move loop.
set -uo pipefail
BOTTOM_GAP="${WISPR_STATUS_BOTTOM_GAP:-36}"
LOG="${XDG_RUNTIME_DIR:-/tmp}/wispr-status-dock.log"
export WISPR_STATUS_BOTTOM_GAP

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" >>"$LOG"; }

place() {
python3 - <<'PY'
import json, os, subprocess

GAP = int(os.environ.get("WISPR_STATUS_BOTTOM_GAP", "36"))

def j(cmd):
    return json.loads(subprocess.check_output(["hyprctl", cmd, "-j"], text=True))

def eval_lua(expr: str):
    # Window moves only. Never cursor APIs.
    subprocess.run(["hyprctl", "eval", expr], capture_output=True, text=True)

try:
    clients = j("clients")
    monitors = j("monitors")
    active = j("activeworkspace")
except Exception as e:
    print("skip", e)
    raise SystemExit(0)

status = next(
    (
        c
        for c in clients
        if c.get("class") == "wispr-flow"
        and c.get("title") == "Status"
        and c.get("mapped")
        and not c.get("hidden")
    ),
    None,
)
if not status:
    raise SystemExit(0)

mon = next((m for m in monitors if m.get("focused")), None)
if mon is None:
    mon = monitors[0] if monitors else None
if mon is None:
    raise SystemExit(0)

want_ws = active.get("id")
addr = status["address"]
cur_ws = (status.get("workspace") or {}).get("id")
ww, wh = map(int, status["size"])
mx, my = int(mon["x"]), int(mon["y"])
mw, mh = int(mon["width"]), int(mon["height"])
cur_x, cur_y = map(int, status["at"])
cur_mon = status.get("monitor")
want_mon = mon.get("id")

tx = mx + (mw - ww) // 2
ty = my + mh - wh - GAP
tx = max(mx, min(tx, mx + mw - max(ww // 4, 1)))
ty = max(my, min(ty, my + mh - max(wh // 4, 1)))

need_ws = want_ws is not None and cur_ws != want_ws
need_mon_or_pos = cur_mon != want_mon or abs(cur_x - tx) > 24 or abs(cur_y - ty) > 24

if not need_ws and not need_mon_or_pos:
    print("ok mon=%s ws=%s @%d,%d" % (mon.get("name"), want_ws, cur_x, cur_y))
    raise SystemExit(0)

if need_ws:
    eval_lua(
        'hl.dispatch(hl.dsp.window.move({ workspace = %d, silent = true, window = "address:%s" }))'
        % (int(want_ws), addr)
    )
if need_mon_or_pos or need_ws:
    eval_lua(
        'hl.dispatch(hl.dsp.window.move({ x = %d, y = %d, relative = false, window = "address:%s" }))'
        % (tx, ty, addr)
    )
print("dock mon=%s ws=%s -> %d,%d" % (mon.get("name"), want_ws, tx, ty))
PY
}

log "start event-driven hyprctl dock (no ydotool, no cursor ops)"
place | while read -r l; do log "$l"; done || true

# Hyprland event socket
SOCK=""
for s in "${XDG_RUNTIME_DIR}/hypr"/*/.socket2.sock; do
  [[ -S "$s" ]] && SOCK=$s && break
done

if [[ -z "$SOCK" ]] || ! command -v socat >/dev/null; then
  log "no event socket; slow poll fallback 2s"
  while true; do
    place | while read -r l; do log "$l"; done || true
    sleep 2
  done
fi

log "watching $SOCK"
# Debounce: on relevant event, place once
while true; do
  socat -u UNIX-CONNECT:"$SOCK" - 2>/dev/null | while IFS= read -r ev; do
    case "$ev" in
      workspace\>\>*|openwindow\>\>*|focusedmon\>\>*|movewindow\>\>*)
        # Follow focused workspace/monitor. hyprctl moves only; never cursor.
        place | while read -r l; do log "$l"; done || true
        ;;
    esac
  done
  log "socat ended; restart 1s"
  sleep 1
done
