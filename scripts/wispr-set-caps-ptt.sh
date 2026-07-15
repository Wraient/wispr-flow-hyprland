#!/usr/bin/env bash
# Wispr shortcuts: F20 = PTT (physical Esc via wispr-key-remap), Escape = dismiss (physical Caps).
set -euo pipefail
python3 - <<'PY'
import json
from pathlib import Path
cfg = Path.home() / ".config" / "Wispr Flow" / "config.json"
if not cfg.exists():
    raise SystemExit(0)
d = json.loads(cfg.read_text())
u = d.setdefault("prefs", {}).setdefault("user", {})
sc = dict(u.get("shortcuts") or {})
for k, v in list(sc.items()):
    if v in ("ptt", "dismiss") or k in ("20", "27", "131"):
        del sc[k]
sc["131"] = "ptt"
sc["27"] = "dismiss"
u["shortcuts"] = sc
cfg.write_text(json.dumps(d, indent=2) + "\n")
print("PTT=F20(physical Esc); dismiss=Escape(physical Caps)")
PY
