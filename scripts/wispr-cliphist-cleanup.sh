#!/usr/bin/env bash
# After Wispr Flow pastes, remove that temporary entry from:
#   1) cliphist (if used)
#   2) Vicinae clipboard history (~/.local/share/vicinae/clipboard.db)
#
# Safety: only deletes entries whose text length matches Flow's paste length.
set -uo pipefail

DELAY_SECS="${WISPR_CLIPHIST_DELAY:-10}"
LOG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Wispr Flow/logs"
LOG_FILE="$LOG_DIR/main.log"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/wispr-cliphist-cleanup"
VICINAE_DB="${XDG_DATA_HOME:-$HOME/.local/share}/vicinae/clipboard.db"
VICINAE_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/vicinae/clipboard-data"
mkdir -p "$STATE_DIR"

log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$STATE_DIR/run.log" 2>/dev/null || true
}

while [[ ! -f "$LOG_FILE" ]]; do
  sleep 2
done

log "started (delay=${DELAY_SECS}s) watching $LOG_FILE (vicinae+cliphist)"

delete_cliphist_by_id() {
  local id="$1"
  local preview="$2"
  [[ -n "$id" ]] || return 0
  local line
  line="$(cliphist list 2>/dev/null | awk -F '\t' -v id="$id" '$1 == id { print; exit }' || true)"
  if [[ -n "${line:-}" ]]; then
    printf '%s\n' "$line" | cliphist delete >/dev/null 2>&1 || true
    log "cliphist deleted id=$id preview=${preview:0:60}"
  else
    if [[ -n "$preview" ]] && cliphist delete-query "$preview" >/dev/null 2>&1; then
      log "cliphist deleted via query preview=${preview:0:60}"
    else
      log "cliphist id=$id already gone"
    fi
  fi
}

delete_vicinae_by_length_or_preview() {
  local paste_len="$1"
  local preview="$2"
  [[ -f "$VICINAE_DB" ]] || {
    log "vicinae db missing: $VICINAE_DB"
    return 0
  }

  python3 - "$VICINAE_DB" "$VICINAE_DATA" "$paste_len" "$preview" <<'PY'
import os, sys, sqlite3

db, data_dir, paste_len_s, preview = sys.argv[1:5]
paste_len = int(paste_len_s)
preview = preview or ""

con = sqlite3.connect(db, timeout=5)
con.execute("PRAGMA foreign_keys=ON")
cur = con.cursor()

# Prefer exact preview match among recent text offers; else length match.
row = None
if preview:
    row = cur.execute(
        """
        SELECT s.id, d.id, d.text_preview, d.size
        FROM selection s
        JOIN data_offer d ON d.selection_id = s.id
        WHERE d.mime_type LIKE 'text/%'
          AND (
            d.text_preview = ?
            OR d.text_preview = ? || char(10)
            OR trim(d.text_preview, char(10)) = ?
          )
        ORDER BY s.updated_at DESC
        LIMIT 1
        """,
        (preview, preview, preview),
    ).fetchone()

if row is None:
    row = cur.execute(
        """
        SELECT s.id, d.id, d.text_preview, d.size
        FROM selection s
        JOIN data_offer d ON d.selection_id = s.id
        WHERE d.mime_type LIKE 'text/%'
          AND d.size IN (?, ?, ?)
        ORDER BY s.updated_at DESC
        LIMIT 1
        """,
        (paste_len, paste_len - 1, paste_len + 1),
    ).fetchone()

if row is None:
    print("NOMATCH")
    con.close()
    raise SystemExit(0)

sid, oid, text_preview, size = row
# Safety: do not delete pinned items
pinned = cur.execute("SELECT pinned_at FROM selection WHERE id=?", (sid,)).fetchone()
if pinned and pinned[0]:
    print(f"PINNED {sid}")
    con.close()
    raise SystemExit(0)

# Collect all offer files for this selection
offer_ids = [r[0] for r in cur.execute("SELECT id FROM data_offer WHERE selection_id=?", (sid,)).fetchall()]
cur.execute("DELETE FROM selection WHERE id=?", (sid,))
# cascade may not fire if foreign_keys was off earlier; clean offers explicitly
cur.execute("DELETE FROM data_offer WHERE selection_id=?", (sid,))
con.commit()
con.close()

removed_files = 0
for oid in offer_ids:
    p = os.path.join(data_dir, oid)
    if os.path.exists(p):
        try:
            os.remove(p)
            removed_files += 1
        except OSError:
            pass

print(f"DELETED sid={sid} size={size} files={removed_files} preview={(text_preview or '')[:60]!r}")
PY
}

schedule_cleanup() {
  local paste_len="$1"
  local cliphist_id="$2"
  local preview="$3"

  (
    sleep "$DELAY_SECS"
    if [[ -n "$cliphist_id" ]]; then
      delete_cliphist_by_id "$cliphist_id" "$preview"
    fi
    out="$(delete_vicinae_by_length_or_preview "$paste_len" "$preview" 2>&1 || true)"
    if [[ -n "$out" ]]; then
      log "vicinae $out"
    fi
  ) &
}

find_cliphist_match() {
  local paste_len="$1"
  cliphist list 2>/dev/null | awk -F '\t' -v n="$paste_len" '
    NR > 20 { exit }
    {
      body = $0
      sub(/^[^\t]+\t/, "", body)
      blen = length(body)
      if (blen == n || blen == n-1 || blen == n+1) {
        print $1 "\t" body
        exit
      }
    }
  ' || true
}

capture_and_schedule() {
  local paste_len="${1:-}"
  if [[ -z "$paste_len" || ! "$paste_len" =~ ^[0-9]+$ || "$paste_len" -le 0 ]]; then
    log "skip: invalid paste_len=${paste_len:-empty}"
    return 0
  fi

  sleep 0.35
  local match id preview
  match="$(find_cliphist_match "$paste_len")"
  if [[ -z "${match:-}" ]]; then
    sleep 0.35
    match="$(find_cliphist_match "$paste_len")"
  fi

  if [[ -n "${match:-}" ]]; then
    id="${match%%$'\t'*}"
    preview="${match#*$'\t'}"
  else
    id=""
    # Fall back to live clipboard text if length matches
    preview="$(wl-paste --no-newline --type text 2>/dev/null || true)"
    if [[ ${#preview} -ne $paste_len && ${#preview} -ne $((paste_len - 1)) && ${#preview} -ne $((paste_len + 1)) ]]; then
      preview=""
    fi
  fi

  if [[ -z "$id" && -z "$preview" ]]; then
    log "skip: no matching cliphist/clipboard text for paste_len=$paste_len"
    # Still try Vicinae length-only delete after delay
    schedule_cleanup "$paste_len" "" ""
    return 0
  fi

  log "scheduled paste_len=$paste_len cliphist_id=${id:-none} preview_len=${#preview} delay=${DELAY_SECS}s"
  schedule_cleanup "$paste_len" "$id" "$preview"
}

while true; do
  tail -n0 -F "$LOG_FILE" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      *"Paste initiated, text length:"*)
        paste_len="$(printf '%s\n' "$line" | sed -n 's/.*text length: \([0-9][0-9]*\).*/\1/p' || true)"
        capture_and_schedule "$paste_len" || log "capture failed"
        ;;
    esac
  done
  log "tail exited; restarting in 1s"
  sleep 1
done
