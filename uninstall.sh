#!/bin/bash
# Claude VoiceOver keys: uninstaller. Removes only what the installer added.
set -euo pipefail
APPDIR="$HOME/Library/Application Support/Claude VoiceOver Keys"
SCRIPTDIR="$HOME/Library/Scripts/Claude VoiceOver Keys"
VOPLIST="$HOME/Library/Group Containers/group.com.apple.VoiceOver/Library/Preferences/com.apple.VoiceOver4/default.plist"
echo "Removing Claude VoiceOver keys."
if [[ -f "$VOPLIST" ]] && ! head -c 1 "$VOPLIST" >/dev/null 2>&1; then
  echo "macOS protects VoiceOver's settings, so Terminal needs Full Disk Access to remove the keys."
  echo "Switch Terminal on in System Settings, Privacy and Security, Full Disk Access, choose Quit & Reopen,"
  echo "then run this again."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  exit 1
fi
if [[ -f "$VOPLIST" ]]; then
  for key in $(plutil -convert xml1 -o - "$VOPLIST" | grep -o 'custom.keyboard-commander.SCRKeyboardCommander_00[0-9a-f]*'); do
    val="$(defaults read "$VOPLIST" "$key" 2>/dev/null || true)"
    [[ "$val" == *"$SCRIPTDIR"* ]] && defaults delete "$VOPLIST" "$key" && echo "  removed $key"
  done
fi
# Hotkey mode: take the Claude block out of skhd's settings file, leaving anything else in it alone.
for CONF in "${XDG_CONFIG_HOME:-$HOME/.config}/skhd/skhdrc" "$HOME/.config/skhd/skhdrc" "$HOME/.skhdrc"; do
  if [[ -f "$CONF" ]] && grep -qx "# >>> Claude VoiceOver keys >>>" "$CONF"; then
    cp "$CONF" "$APPDIR/skhdrc-backup-$(date +%Y%m%d-%H%M%S)"
    awk '$0=="# >>> Claude VoiceOver keys >>>"{skip=1;next} $0=="# <<< Claude VoiceOver keys <<<"{skip=0;next} !skip' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
    echo "  removed the Claude keys from $CONF"
    command -v skhd >/dev/null && skhd --restart-service >/dev/null 2>&1 || true
  fi
done
rm -rf "$SCRIPTDIR"
rm -f "$APPDIR/claudevo" "$HOME/.claudevo-muted"
echo "Done. Your VoiceOver settings backups are kept in: $APPDIR"
echo "You can also remove claudevo from System Settings, Privacy and Security, Accessibility."
echo "If you installed skhd only for these keys, you can remove it with: skhd --uninstall-service, then brew uninstall skhd"
echo "Turn VoiceOver off and on again (Command-F5 twice)."
