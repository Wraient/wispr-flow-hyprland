# Dank Material Shell: hide Wispr from dock

Dank’s dock lists running toplevels and has **no exclude-app setting**.

`../scripts/wispr-hide-from-dms-dock.sh`:

1. Copies `/usr/share/quickshell/dms` → `~/.config/quickshell/dms-local`
2. Patches:
   - `Modules/Dock/DockApps.qml`
   - `Modules/DankBar/Widgets/AppsDock.qml`
   - `Modules/DankBar/Widgets/RunningApps.qml`
3. Inserts `shouldHideFromDock()` that skips:
   - appId `wispr-flow` / contains `wispr`
   - titles `Status`, `Hub`, `Flow Status Indicator`

Hyprland autostart should run:

```bash
qs -p "$HOME/.config/quickshell/dms-local" -n -d
```

instead of `dms run`.

After `dms-shell` upgrades, re-run the script and restart the shell.
