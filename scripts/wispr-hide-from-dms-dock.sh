#!/usr/bin/env bash
# Re-apply Wispr hide-from-DMS-dock patch onto ~/.config/quickshell/dms-local after DMS upgrades.
set -euo pipefail
SRC=/usr/share/quickshell/dms
DST="$HOME/.config/quickshell/dms-local"
mkdir -p "$DST"
# refresh tree (symlinks) then replace patched files
rsync -a --delete --copy-links "$SRC"/ "$DST"/ 2>/dev/null || {
  rm -rf "$DST"
  mkdir -p "$DST"
  cp -as "$SRC"/. "$DST"/
}
python3 - <<'PY'
from pathlib import Path
home = Path.home()
files = {
    home/'.config/quickshell/dms-local/Modules/Dock/DockApps.qml': Path('/usr/share/quickshell/dms/Modules/Dock/DockApps.qml'),
    home/'.config/quickshell/dms-local/Modules/DankBar/Widgets/AppsDock.qml': Path('/usr/share/quickshell/dms/Modules/DankBar/Widgets/AppsDock.qml'),
    home/'.config/quickshell/dms-local/Modules/DankBar/Widgets/RunningApps.qml': Path('/usr/share/quickshell/dms/Modules/DankBar/Widgets/RunningApps.qml'),
}
helper_indent = {
    'DockApps': '                ',
    'other': '    ',
}
for dst, src in files.items():
    text = src.read_text()
    is_dockapps = dst.name == 'DockApps.qml'
    ind = '                ' if is_dockapps else '    '
    helper = f'''
{ind}function shouldHideFromDock(toplevel) {{
{ind}    if (!toplevel)
{ind}        return false;
{ind}    const rawAppId = (toplevel.appId || "").toLowerCase();
{ind}    const title = (toplevel.title || "");
{ind}    if (rawAppId === "wispr-flow" || rawAppId.includes("wispr"))
{ind}        return true;
{ind}    if (title === "Status" || title === "Hub" || title === "Flow Status Indicator")
{ind}        return true;
{ind}    return false;
{ind}}}
'''
    if is_dockapps:
        text = text.replace('                function buildBaseItems() {', helper + '\n                function buildBaseItems() {', 1)
        # inject into both forEach bodies
        parts = []
        pos = 0
        marker = 'sortedToplevels.forEach((toplevel, index) => {'
        while True:
            i = text.find(marker, pos)
            if i < 0:
                break
            j = i + len(marker)
            if 'shouldHideFromDock(toplevel)' not in text[j:j+200]:
                text = text[:j] + '\n                        if (shouldHideFromDock(toplevel))\n                            return;' + text[j:]
            pos = j + 80
    else:
        if '    id: root\n' in text:
            text = text.replace('    id: root\n', '    id: root\n' + helper + '\n', 1)
        marker = 'sortedToplevels.forEach((toplevel, index) => {'
        i = text.find(marker)
        if i >= 0:
            j = i + len(marker)
            if 'shouldHideFromDock(toplevel)' not in text[j:j+200]:
                text = text[:j] + '\n                        if (shouldHideFromDock(toplevel))\n                            return;' + text[j:]
        # RunningApps for-loop
        m2 = 'const toplevel = sortedToplevels[i];'
        k = text.find(m2)
        if k >= 0:
            end = k + len(m2)
            if 'shouldHideFromDock(toplevel)' not in text[end:end+120]:
                text = text[:end] + '\n                if (shouldHideFromDock(toplevel))\n                    continue;' + text[end:]
    if dst.is_symlink():
        dst.unlink()
    dst.write_text(text)
    print('patched', dst)
PY
echo "Restart shell: qs -p $DST -n -d   (or re-login)"
