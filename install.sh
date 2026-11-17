#!/bin/bash
# Claude VoiceOver keys: installer.
# Builds the claudevo tool on this Mac, installs the VoiceOver scripts, then sets up the keys one of two ways:
#   Hotkeys (recommended): the free skhd hotkey program runs the keys. Option plus a letter works only while Claude
#     is in front, so games and other apps keep their own Option keys, and Option-Shift plus W, L, R or P works
#     from any app.
#   VoiceOver Option keys: VoiceOver's own Option Key commands run the keys, as in version 1. Nothing else to
#     install, but the keys apply in every app and can clash with other apps' Option keys.
# Safe to run again. Options: --hotkeys or --commander to choose without being asked, --dry-run to change nothing,
# --check to list key clashes and test the keys against the open Claude window without installing anything.
# To use different letters or modifiers, copy keys.conf.example to ~/.config/claude-voiceover-keys/keys.conf, edit it,
# and run the installer again.
set -euo pipefail

DRY=0; MODE=""; CHECK=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --hotkeys) MODE=hotkeys ;;
    --commander) MODE=commander ;;
    --check) CHECK=1 ;;
  esac
done
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
  "o:routines:Scheduled:focus"
  "s:rail:Session rail:speak"
  "l:speak:Listen to latest reply:speak"
  "w:waiting:Who is waiting:speak"
  "i:info:Session info:speak"
  "h:session:Which session:speak"
  "r:record:Record dictation:record"
)
# Keys that also work from any app in hotkey mode, with Option-Shift.
GLOBAL=(w l r p)
MOD="alt"; GMOD="alt + shift"
# Your own choices, if you have made any, replace the defaults above. See keys.conf.example.
KEYCONF="${CVK_KEYCONF:-$HOME/.config/claude-voiceover-keys/keys.conf}"
if [[ -f "$KEYCONF" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"; [[ "$line" != *=* ]] && continue
    k="$(echo "${line%%=*}" | tr -d '[:space:]')"; v="$(echo "${line#*=}" | sed 's/^ *//;s/ *$//')"
    case "$k" in
      modifier) MOD="$v" ;;
      global_modifier) GMOD="$v" ;;
      global) read -r -a GLOBAL <<< "$v" ;;
      *) for i in "${!KEYS[@]}"; do
           IFS=: read -r letter cmd name kind <<< "${KEYS[$i]}"
           if [[ "$cmd" == "$k" ]]; then
             if [[ -z "$v" || "$v" == "off" ]]; then unset 'KEYS[i]'
             else KEYS[$i]="$(echo "$v" | tr '[:upper:]' '[:lower:]'):$cmd:$name:$kind"; fi
           fi
         done ;;
    esac
  done < "$KEYCONF"
  KEYS=("${KEYS[@]}")
  # Global keys are named by command in keys.conf (speak waiting record prompt); turn them into letters.
  G2=(); for g in "${GLOBAL[@]:-}"; do
    for entry in "${KEYS[@]}"; do IFS=: read -r l c n k <<< "$entry"; [[ "$c" == "$g" || "$l" == "$g" ]] && G2+=("$l") && break; done
  done; GLOBAL=("${G2[@]:-}")
fi
# Control-Option is VoiceOver's own modifier, so keys on it would fight VoiceOver.
for m in "$MOD" "$GMOD"; do
  norm="$(echo "$m" | tr -d ' ' | tr '+' '\n' | sed 's/^[lr]//' | sort | tr '\n' '+')"
  if [[ "$norm" == "alt+ctrl+" ]]; then echo "Control-Option is VoiceOver's own modifier, so it can't be used for these keys. Choose another in $KEYCONF."; exit 1; fi
done
# Letters must be unique.
dups="$(for e in "${KEYS[@]}"; do echo "${e%%:*}"; done | sort | uniq -d | tr '\n' ' ')"
if [[ -n "$dups" ]]; then echo "These letters are given to more than one key in $KEYCONF: $dups. Change one and run this again."; exit 1; fi
BEGIN_MARK="# >>> Claude VoiceOver keys >>>"
END_MARK="# <<< Claude VoiceOver keys <<<"

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

# Other programs that catch keys across the whole Mac can take these keys first, or lose theirs to them.
other_hotkey_apps() {
  local found=()
  local running; running="$(ps -axo command= 2>/dev/null)"
  for app in "Karabiner-Elements" "Hammerspoon" "BetterTouchTool" "Keyboard Maestro" "Raycast" "Alfred" "MaccessHub" "TurnOver" "com.turnover"; do
    grep -qiF "$app" <<< "$running" && found+=("$app")
  done
  [[ ${#found[@]} -gt 0 ]] && echo "${found[*]}" | sed 's/com.turnover/TurnOver/; s/TurnOver TurnOver/TurnOver/' || true
}
# Say a key the way a person would: "alt + shift - w" becomes "Option-Shift-W".
nice() {
  local m="$1" l="$2" out=""
  for part in $(echo "$m" | tr '+' ' '); do
    case "$part" in alt|lalt|ralt) out+="Option-" ;; shift|lshift|rshift) out+="Shift-" ;; cmd|lcmd|rcmd) out+="Command-" ;;
      ctrl|lctrl|rctrl) out+="Control-" ;; fn) out+="Fn-" ;; hyper) out+="Hyper-" ;; meh) out+="Meh-" ;; *) out+="$part-" ;; esac
  done
  echo "$out$(echo "$l" | tr '[:lower:]' '[:upper:]')"
}
list_keys() {
  for entry in "${KEYS[@]}"; do IFS=: read -r letter cmd name kind <<< "$entry"; if [[ $MODE == commander ]]; then echo "  $(nice alt "$letter"): $name"; else echo "  $(nice "$MOD" "$letter") in Claude: $name"; fi; done
  if [[ $MODE != commander ]]; then
    for letter in "${GLOBAL[@]:-}"; do [[ -z "$letter" ]] && continue
      for entry in "${KEYS[@]}"; do IFS=: read -r l c n k <<< "$entry"; [[ $l == "$letter" ]] && break; done
      echo "  $(nice "$GMOD" "$letter") in any app: $n"; done
  fi
}
if [[ $CHECK == 1 ]]; then
  say_line "Checking keys. Nothing is installed or changed."
  [[ -z "$MODE" ]] && MODE=hotkeys
  list_keys
  apps="$(other_hotkey_apps)"
  [[ -n "$apps" ]] && echo "  These programs that catch keys are running, so check none of them uses the keys above: $apps."
  for CONF in "${XDG_CONFIG_HOME:-$HOME/.config}/skhd/skhdrc" "$HOME/.skhdrc"; do
    [[ -f "$CONF" ]] || continue
    other="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$CONF")"
    for entry in "${KEYS[@]}"; do IFS=: read -r l c n k <<< "$entry"
      grep -Eq "^[[:space:]]*$MOD[[:space:]]*-[[:space:]]*$l[[:space:]]*[:\[]" <<< "$other" && echo "  Clash: $(nice "$MOD" "$l") is already used in $CONF."
    done
  done
  if [[ -x "$TOOL" ]]; then say_line "Testing the keys against the Claude window:"; "$TOOL" check --print || true
  else echo "  The keys aren't installed yet, so the Claude window test is skipped."; fi
  exit 0
fi

# Choose how the keys are run.
if [[ -z "$MODE" ]]; then
  if [[ -t 0 ]]; then
    say_line "How should the keys be run?"
    echo "  1. Hotkeys, recommended. Option plus a letter works only in Claude, so other apps and games keep their"
    echo "     own Option keys, and Option-Shift plus W, L, R or P works from any app. Uses the free skhd program."
    echo "  2. VoiceOver Option keys, as in version 1. Nothing extra to install, but the keys apply in every app."
    read -r -p "  Type 1 or 2 and press Return: " choice
    [[ "$choice" == "2" ]] && MODE=commander || MODE=hotkeys
  else
    MODE=hotkeys
  fi
fi
if [[ $MODE == hotkeys ]] && ! command -v skhd >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    say_line "Installing the skhd hotkey program with Homebrew."
    run brew install koekeishiya/formulae/skhd
  else
    say_line "Hotkeys need the skhd program, which installs with Homebrew, and Homebrew isn't on this Mac."
    echo "  Either install Homebrew from brew.sh and run this again, or run: bash install.sh --commander"
    echo "  to use VoiceOver's Option keys instead."
    exit 1
  fi
fi
[[ $MODE == hotkeys ]] && echo "  Setting up hotkeys." || echo "  Setting up VoiceOver Option keys."

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
# Routines was renamed Scheduled in the app, and in version 2.1 here.
[[ $DRY == 0 ]] && rm -f "$SCRIPTDIR/Claude Routines.scpt"
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
say_line "Updating VoiceOver's settings."
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
# Take out the Option key commands an earlier run added. In hotkey mode this stops VoiceOver catching the keys
# first; with VoiceOver Option keys it clears letters you have since moved, and the current ones are added back below.
if true; then
  if [[ -f "$VOPLIST" ]]; then
    for key in $(plutil -convert xml1 -o - "$VOPLIST" 2>/dev/null | grep -o 'custom.keyboard-commander.SCRKeyboardCommander_00[0-9a-f]*' || true); do
      val="$(defaults read "$VOPLIST" "$key" 2>/dev/null || true)"
      if [[ "$val" == *"$SCRIPTDIR"* ]]; then
        if [[ $DRY == 1 ]]; then echo "  would remove VoiceOver Option key command $key"
        else defaults delete "$VOPLIST" "$key"; fi
      fi
    done
  fi
fi
if [[ $MODE == hotkeys ]]; then KEYS_FOR_COMMANDER=(); else KEYS_FOR_COMMANDER=("${KEYS[@]}"); fi
for entry in "${KEYS_FOR_COMMANDER[@]:-}"; do
  [[ -z "$entry" ]] && continue
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
  if [[ $MODE == commander && "$(defaults read "$VOPLIST" SCRCKeyboardCommanderEnabled 2>/dev/null)" != "1" ]]; then
    defaults write "$VOPLIST" SCRCKeyboardCommanderEnabled -bool true && echo "  Turned on: VoiceOver's Option key commands."
    defaults read "$VOPLIST" SCRCKeyboardCommanderCommandKey >/dev/null 2>&1 \
      || defaults write "$VOPLIST" SCRCKeyboardCommanderCommandKey -string SCRKeyboardModifierKeyOption
  fi
fi

# 4b. Hotkey mode: write the keys into skhd's settings file, between markers, leaving anything else in it alone.
if [[ $MODE == hotkeys ]]; then
  if [[ -n "${XDG_CONFIG_HOME:-}" && -f "$XDG_CONFIG_HOME/skhd/skhdrc" ]]; then CONF="$XDG_CONFIG_HOME/skhd/skhdrc"
  elif [[ -f "$HOME/.config/skhd/skhdrc" ]]; then CONF="$HOME/.config/skhd/skhdrc"
  else CONF="$HOME/.skhdrc"; fi
  say_line "Writing the hotkeys into $CONF."
  OTHER=""
  if [[ -f "$CONF" ]]; then
    OTHER="$(awk -v b="$BEGIN_MARK" -v e="$END_MARK" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$CONF")"
  fi
  taken() { grep -Eq "^[[:space:]]*$1[[:space:]]*[:\[]" <<< "$OTHER"; }
  BLOCK="$BEGIN_MARK"$'\n'"# Added by the Claude VoiceOver keys installer. Run install.sh again to rewrite, uninstall.sh to remove."
  for entry in "${KEYS[@]}"; do
    IFS=: read -r letter cmd name kind <<< "$entry"
    if taken "$MOD - $letter"; then echo "  $(nice "$MOD" "$letter") is already used in your hotkeys, so $name was not assigned."; continue; fi
    BLOCK+=$'\n'"$MOD - $letter ["$'\n'"    \"claude\" : osascript \"$SCRIPTDIR/Claude $name.scpt\""$'\n'"    * ~"$'\n'"]"
  done
  for letter in "${GLOBAL[@]:-}"; do
    [[ -z "$letter" ]] && continue
    for entry in "${KEYS[@]}"; do IFS=: read -r l cmd name kind <<< "$entry"; [[ $l == "$letter" ]] && break; done
    if taken "${GMOD//+/\\+} - $letter"; then echo "  $(nice "$GMOD" "$letter") is already used in your hotkeys, so it was not assigned."; continue; fi
    BLOCK+=$'\n'"$GMOD - $letter : osascript \"$SCRIPTDIR/Claude $name.scpt\""
  done
  BLOCK+=$'\n'"$END_MARK"
  if [[ $DRY == 0 ]]; then
    mkdir -p "$(dirname "$CONF")" "$APPDIR"
    [[ -f "$CONF" ]] && cp "$CONF" "$APPDIR/skhdrc-backup-$(date +%Y%m%d-%H%M%S)"
    { [[ -n "$OTHER" ]] && printf '%s\n\n' "$OTHER"; printf '%s\n' "$BLOCK"; } > "$CONF"
    if [[ -f "$HOME/Library/LaunchAgents/com.koekeishiya.skhd.plist" ]]; then
      skhd --restart-service >/dev/null 2>&1 || skhd --start-service >/dev/null 2>&1 || true
    else
      skhd --install-service >/dev/null 2>&1 || true
      skhd --start-service >/dev/null 2>&1 || true
    fi
    sleep 1
    if pgrep -x skhd >/dev/null; then echo "  The hotkey program is running, and starts again each time you log in."
    else echo "  The hotkey program did not start. Run: skhd --start-service, and see the README's Good to know section."; fi
  else
    echo "  would write the block above into $CONF and start the skhd service"
  fi
fi

# 4c. Warn about other programs that catch keys.
apps="$(other_hotkey_apps)"
if [[ -n "$apps" ]]; then
  say_line "Heads up: these programs that catch keys are running: $apps."
  echo "  If one of them uses any of the keys above, one side will win and the other will go quiet."
  echo "  To change a Claude key, see keys.conf.example in this folder. To list the keys and test them: bash install.sh --check"
fi

# 5. Permissions
if [[ $MODE == hotkeys ]]; then
  say_line "Permissions: skhd needs Accessibility to hear the keys, and claudevo needs it to move around Claude."
  echo "  When macOS asks about either one, choose Open System Settings, switch it on in Privacy and Security,"
  echo "  Accessibility, and press the key again. If a key does nothing and nothing asks, check skhd is switched on there."
else
  say_line "One more permission, the first time you use a key: macOS asks whether claudevo may use accessibility features."
  echo "  Choose Open System Settings, then switch on claudevo in Privacy and Security, Accessibility, and press the key again."
fi
say_line "Last step: turn VoiceOver off and on again (Command-F5 twice) so it picks up the changes."
echo "  If you gave Terminal Full Disk Access for this, you can switch it off again now in Privacy and Security, Full Disk Access."
if [[ $MODE == hotkeys ]]; then
  say_line "Done. Your keys:"; list_keys
else
  say_line "Done. Hold your VoiceOver Option key (Right, Left or either, as set in VoiceOver Utility, Commands) and press a letter:"; list_keys
fi
