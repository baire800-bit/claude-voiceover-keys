#!/bin/bash
# Claude VoiceOver keys: installer.
# Builds the claudevo tool on this Mac, installs the VoiceOver scripts, assigns Option keys in
# VoiceOver's Option Key commands (Right, Left or either Option, as the user has set), and walks you through the one permission macOS needs.
# Safe to run again: it rebuilds and re-assigns. Run with --dry-run to see what it would do.
set -euo pipefail

DRY=0; [[ "${1:-}" == "--dry-run" ]] && DRY=1
HERE="$(cd "$(dirname "$0")" && pwd)"
APPDIR="${CVK_APPDIR:-$HOME/Library/Application Support/Claude VoiceOver Keys}"
TOOL="$APPDIR/claudevo"
SCRIPTDIR="${CVK_SCRIPTDIR:-$HOME/Library/Scripts/Claude VoiceOver Keys}"
VOPLIST="${CVK_VOPLIST:-$HOME/Library/Group Containers/group.com.apple.VoiceOver/Library/Preferences/com.apple.VoiceOver4/default.plist}"

# letter : command : script name : kind
KEYS=(
  "p:prompt:Message box:focus"
  "b:sidebar:Sidebar:focus"
  "c:mode:Chat or Code mode:focus"
  "o:routines:Routines:focus"
  "l:speak:Listen to latest reply:speak"
  "w:waiting:Who is waiting:speak"
  "i:info:Session info:speak"
  "h:session:Which session:speak"
  "r:record:Record dictation:record"
)

say_line() { echo; echo "$1"; }
run() { if [[ $DRY == 1 ]]; then echo "  would run: $*"; else "$@"; fi }

say_line "Claude VoiceOver keys installer"
[[ $DRY == 1 ]] && echo "Dry run: nothing will be changed."

# 1. Requirements
if [[ "$(uname)" != "Darwin" ]]; then echo "This only runs on macOS."; exit 1; fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  say_line "Apple's command line developer tools are needed to build the tool. macOS will now offer to install them. When that finishes, run this installer again."
  run xcode-select --install || true
  exit 1
fi
if [[ ! -d /Applications/Claude.app ]]; then
  say_line "Note: the Claude desktop app was not found in Applications. The keys will do nothing until it is installed."
fi

# 2. Build the tool, unless an identical build is already installed. Skipping the rebuild keeps the run fast and
# keeps macOS's Accessibility permission for claudevo, which a fresh build can lose.
SRCHASH="$(shasum -a 256 "$HERE/src/claudevo.swift" | cut -d' ' -f1)"
if [[ -x "$TOOL" && -f "$APPDIR/source.sha256" && "$(cat "$APPDIR/source.sha256")" == "$SRCHASH" ]]; then
  say_line "The claudevo tool is already built and up to date."
else
  say_line "Building the claudevo tool. This takes about a minute."
  run mkdir -p "$APPDIR"
  run xcrun swiftc -O "$HERE/src/claudevo.swift" -o "$TOOL"
  run codesign -s - -f --identifier com.github.claudevoiceoverkeys.claudevo "$TOOL" 2>/dev/null
  [[ $DRY == 0 ]] && echo "$SRCHASH" > "$APPDIR/source.sha256"
fi

# 3. Install the VoiceOver scripts
say_line "Installing the VoiceOver scripts."
run mkdir -p "$SCRIPTDIR"
for entry in "${KEYS[@]}"; do
  IFS=: read -r letter cmd name kind <<< "$entry"
  tmpl="$HERE/scripts/$kind.applescript.template"
  src="$(sed -e "s|@CLAUDEVO@|$TOOL|g" -e "s|@CMD@|$cmd|g" -e "s|@NAME@|$name|g" "$tmpl")"
  if [[ $DRY == 1 ]]; then echo "  would compile: $SCRIPTDIR/Claude $name.scpt"
  else printf '%s\n' "$src" | osacompile -o "$SCRIPTDIR/Claude $name.scpt" -; fi
done

# 4. Assign the keys.
# VoiceOver keeps its settings in a protected area of the Library. Terminal can only change them with Full Disk
# Access, so if access is missing the installer opens that page in System Settings and waits while you switch
# Terminal on. You can switch it off again afterwards; the keys stay.
say_line "Assigning Option keys in VoiceOver."
VODIR="$(dirname "$VOPLIST")"
can_access() { head -c 1 "$VOPLIST" >/dev/null 2>&1; }

if [[ $DRY == 0 && ! -f "$VOPLIST" ]] && ls "$VODIR" >/dev/null 2>&1; then
  echo "  VoiceOver's settings file was not found. Turn VoiceOver on once (Command-F5), then run this again."
  exit 1
fi

if [[ $DRY == 0 ]] && ! can_access; then
  echo
  echo "  Nearly there. macOS protects VoiceOver's settings, so Terminal needs Full Disk Access to assign the keys."
  echo "  System Settings is opening at Privacy and Security, Full Disk Access."
  echo "  1. Switch Terminal on. If it isn't in the list, choose the Add button, press Shift-Command-G,"
  echo "     type /System/Applications/Utilities/Terminal.app, press Return, then choose Open."
  echo "  2. macOS asks to quit and reopen Terminal. Choose Quit & Reopen."
  echo "  3. Run the installer again. Everything else is already done, so it only takes a few seconds."
  echo "  You can switch Full Disk Access off again afterwards; the keys stay."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
  exit 0
fi

if [[ $DRY == 0 ]]; then
  cp "$VOPLIST" "$APPDIR/VoiceOver-settings-backup-$(date +%Y%m%d-%H%M%S).plist"
fi
assigned=(); skipped=(); failed=()
for entry in "${KEYS[@]}"; do
  IFS=: read -r letter cmd name kind <<< "$entry"
  key="custom.keyboard-commander.SCRKeyboardCommander_00$(printf '%02x' "'$letter")"
  existing="$(defaults read "$VOPLIST" "$key" 2>/dev/null || true)"
  if [[ -n "$existing" && "$existing" != *"$SCRIPTDIR"* ]]; then
    skipped+=("Option $letter is already used, so $name was not assigned")
    continue
  fi
  value="SCRWorkspace.customOpenScript:$SCRIPTDIR/Claude $name.scpt"
  if [[ $DRY == 1 ]]; then echo "  would assign Option $letter: $name"; continue; fi
  defaults write "$VOPLIST" "$key" -string "$value" 2>/dev/null || true
  assigned+=("$letter:$name:$key:$value")
done
# Confirm against the file itself, not just the preferences cache.
if [[ $DRY == 0 && ${#assigned[@]} -gt 0 ]]; then
  sleep 1
  filexml="$(plutil -convert xml1 -o - "$VOPLIST" 2>/dev/null || true)"
  for a in "${assigned[@]}"; do
    IFS=: read -r letter name key value <<< "$a"
    if grep -q "<key>$key</key>" <<< "$filexml"; then echo "  Option $letter: $name"
    else failed+=("Option $letter: $name"); fi
  done
fi
for s in "${skipped[@]:-}"; do [[ -n "$s" ]] && echo "  $s. You can assign it yourself in VoiceOver Utility, Commands, Edit Option Key commands."; done
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "  These keys did not save: ${failed[*]}. Quit Terminal with Command-Q and run the installer again."
  exit 1
fi

if [[ $DRY == 0 ]]; then
  # Switch on the two VoiceOver settings the keys depend on, if they're off.
  if [[ "$(defaults read "$VOPLIST" SCREnableAppleScript 2>/dev/null)" != "1" ]]; then
    defaults write "$VOPLIST" SCREnableAppleScript -bool true && echo "  Turned on: Allow VoiceOver to be controlled with AppleScript."
  fi
  if [[ "$(defaults read "$VOPLIST" SCRCKeyboardCommanderEnabled 2>/dev/null)" != "1" ]]; then
    defaults write "$VOPLIST" SCRCKeyboardCommanderEnabled -bool true && echo "  Turned on: VoiceOver's Option key commands."
    defaults read "$VOPLIST" SCRCKeyboardCommanderCommandKey >/dev/null 2>&1 \
      || defaults write "$VOPLIST" SCRCKeyboardCommanderCommandKey -string SCRKeyboardModifierKeyOption
  fi
fi

# 5. Permissions
say_line "One more permission, the first time you use a key: macOS asks whether claudevo may use accessibility features."
echo "  Choose Open System Settings, then switch on claudevo in Privacy and Security, Accessibility, and press the key again."
say_line "Last step: turn VoiceOver off and on again (Command-F5 twice) so it picks up the new keys."
echo "  If you gave Terminal Full Disk Access for this, you can switch it off again now in Privacy and Security, Full Disk Access."
say_line "Done. Hold your VoiceOver Option key (Right, Left or either, as set in VoiceOver Utility, Commands) and press a letter."
