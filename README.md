# Claude VoiceOver keys

Keyboard shortcuts that make the Claude desktop app on macOS quicker to use with VoiceOver. Hold Option and press a letter to jump straight to part of the app, or to have VoiceOver tell you something without hunting for it.

## Two ways to run the keys

Version 2 gives you a choice, and the installer asks which you want.

Hotkeys, the recommended way. The free skhd hotkey program runs the keys. Option plus a letter only does anything while Claude is in front, so games and other apps keep their own Option keys. Either Option key works, so you can use whichever hand is comfortable. Four keys also work from any app with Option and Shift: W, L, R and P. You can check on your sessions, hear the latest reply, dictate or get to the message box without leaving what you're doing. skhd installs with Homebrew, and the installer does that for you if Homebrew is on your Mac.

VoiceOver Option keys, the way version 1 worked. VoiceOver's own Option Key commands run the keys, so there's nothing extra to install. But the keys apply in every app, so they can clash with other apps that use Option and a letter. In VoiceOver Utility, under Commands, you choose which Option key they listen to: Right Option, Left Option, or either.

This came from a real clash: a game that uses Option-S and Option-C, where the version 1 keys took them over.

## Feedback

Found a problem, or have an idea for another key? Please open an issue on this project's Issues page: https://github.com/baire800-bit/claude-voiceover-keys/issues

It helps to say which key you pressed, what VoiceOver said, and which version of macOS you're using.

## The keys

All of these are Option plus a letter, in the Claude app.

- P: move to the message box.
- B: move to the session you're in, in the sidebar.
- C: move to the Chat and Cowork / Code buttons.
- O: move to Routines.
- S: show or hide the session rail, the panel of session details (Environment, Context, Connectors) beside the conversation. VoiceOver says "Session rail on" or "Session rail off". With the rail hidden, moving by heading with VoiceOver goes through the conversation without stopping in the panel.
- L: listen to Claude's latest reply.
- W: hear all your sessions, grouped: waiting for you first, then running, then idle.
- I: hear this session's model, effort, permission mode and usage.
- H: hear which session you're in, and its folder.
- R: start dictation, and press again to stop. On the first press VoiceOver goes quiet, you hear three beeps, and recording starts after the third, so VoiceOver doesn't talk over you or get typed into your message. On the second press, recording stops and VoiceOver says "Stopped".

With hotkeys, these also work from any app:

- Option-Shift-W: hear all your sessions.
- Option-Shift-L: listen to Claude's latest reply.
- Option-Shift-R: start or stop dictation.
- Option-Shift-P: move to Claude's message box.

If one of these keys is already in use, in your skhd hotkeys or your VoiceOver Option key commands, the installer leaves it alone and tells you which ones it skipped.

## Before you install

The installer changes settings on your Mac. It adds scripts to your Library and switches on the VoiceOver setting that lets scripts speak. With hotkeys, it installs skhd if needed, adds the keys to skhd's settings file between two marker lines, leaving any hotkeys of your own alone, and starts skhd so it runs each time you log in. With VoiceOver Option keys, it writes the keys into VoiceOver's settings instead. It asks for Full Disk Access for Terminal while it runs, and Accessibility for the claudevo tool, and with hotkeys for skhd too. It backs up VoiceOver's settings and skhd's settings file before changing them, and uninstall.sh removes everything it added. It's offered as is, with no warranty, as the licence says. If you'd like to see exactly what it does first, read install.sh, or run it with --dry-run, which changes nothing.

## Installing

You need a Mac with the Claude desktop app and VoiceOver. The installer builds a small tool on your own Mac, so it also needs Apple's free command line developer tools. If you don't have them, macOS offers to install them, and you run the installer again afterwards.

### Option 1: one line in Terminal

Open Terminal and paste this line, then press Return.

    curl -fsSL https://github.com/baire800-bit/claude-voiceover-keys/archive/refs/heads/main.tar.gz | tar -xz -C /tmp && bash /tmp/claude-voiceover-keys-main/install.sh

### Option 2: download the zip

Download the zip from the Releases page, or choose Code, then Download ZIP. Unzip it and open the folder in Finder.

Because the installer isn't signed by Apple, macOS blocks it the first time you open it. Since macOS Sequoia, the old Control-click workaround no longer works. Allowing it in System Settings does, and it can all be done from the keyboard:

1. In Finder, select Install.command and press Command-Down Arrow to open it. macOS says it can't check the developer. Press Return or choose Done to dismiss the message.
2. Open the Apple menu (VO-M takes you to the menu bar, where the Apple menu is first) and choose System Settings. In the sidebar, move down to Privacy & Security and select it.
3. In Privacy & Security, move down to the Security section. There's a message saying Install.command was blocked, with a button called Open Anyway. Press it with VO-Space. The button only stays there for about an hour after the block, so if it's missing, open Install.command again first.
4. Enter your password or use Touch ID.
5. Back in Finder, open Install.command again with Command-Down Arrow. This time the dialog has an Open button, so choose Open. The installer runs in a Terminal window.

macOS remembers this, so you only do it once. The one-line Terminal install in Option 1 avoids this step entirely.

### What happens when it runs

1. It asks whether you want hotkeys or VoiceOver Option keys. Type 1 or 2 and press Return. To choose without being asked, run it with --hotkeys or --commander. With hotkeys, it installs skhd through Homebrew if it isn't there already.
2. It builds the claudevo tool and installs the VoiceOver scripts. This takes about a minute.
3. VoiceOver keeps its settings in a protected part of the Library, so Terminal needs Full Disk Access to assign the keys. If Terminal doesn't have it yet, the installer opens Privacy and Security, Full Disk Access and stops. Switch Terminal on, and choose Quit & Reopen when macOS asks. Then run the installer again: open Install.command again, or paste the one-line command again. The second run takes a few seconds, because the rest is already done.
4. It assigns the keys and lists them. It also switches on "Allow VoiceOver to be controlled with AppleScript" if it's off, and with VoiceOver Option keys, VoiceOver's Option key commands too. If you're moving from version 1 to hotkeys, it removes the old VoiceOver Option key commands so VoiceOver doesn't catch the keys first.
5. Turn VoiceOver off and on again with Command-F5, twice, so it picks up the changes.
6. The first time you press one of the keys, macOS may ask whether claudevo, or with hotkeys skhd, may use accessibility features. Choose Open System Settings, switch it on in Privacy and Security, Accessibility, then press the key again.

You can switch Terminal's Full Disk Access off again once the installer has finished. The keys stay.

To see what the installer would do without changing anything, run it in Terminal with --dry-run: bash install.sh --dry-run

## Uninstalling

In Terminal, go to this folder and run: bash uninstall.sh

It removes only the keys and files this installer added, including the Claude block in skhd's settings file, and keeps your settings backups. It leaves skhd installed in case you use it for anything else, and tells you how to remove it. Like the installer, it needs Terminal to have Full Disk Access to remove the keys from VoiceOver's settings, and it tells you if that's missing. Afterwards, turn VoiceOver off and on again.

## Good to know

- The keys find things in the Claude app by their accessibility labels, such as "Prompt" and "Press and hold to record". If an app update renames one, that key stops working until this is updated.
- Because of that, the keys only work with the Claude app in English.
- Running the installer again only rebuilds claudevo when its source code has changed. A rebuild can make macOS forget claudevo's Accessibility permission. If a key says it needs permission, switch claudevo off and on again in Privacy and Security, Accessibility.
- With hotkeys, if no key does anything and macOS never asked, check that skhd is switched on in Privacy and Security, Accessibility. If you update skhd, macOS can forget that permission, so switch it off and on again.
- The hotkeys recognise Claude by its app name, so they only fire while the Claude desktop app is in front.
- Nothing here types for you or opens other apps. The tool uses the macOS accessibility interface to move focus and read labels, and VoiceOver's own scripting to speak.

## What's in this folder

- install.sh: the installer.
- Install.command: open this from Finder (Command-Down Arrow) to run the installer.
- uninstall.sh: removes everything the installer added.
- src/claudevo.swift: the tool's source code.
- scripts: templates for the VoiceOver scripts the installer creates.

## Changes

Version 2.0, 15 November 2026. The installer now offers hotkeys through the free skhd program, as well as VoiceOver's Option key commands. With hotkeys, Option plus a letter works only in Claude, so other apps keep their own Option keys, and either Option key works. Option-Shift with W, L, R or P works from any app. If you already have version 1, run the installer again and choose hotkeys. It moves your keys over and removes the old Option key commands. To stay as you are, choose VoiceOver Option keys.

Version 1.1, 15 October 2026. Added S, which shows or hides the session rail that Claude app version 2.42304 put beside the conversation. Fixed W for the new sidebar layout in that version. It now also lists sessions with a new reply. Fixed L, which had started reading the message time and "Chat mode" at the end of the reply. To update, run the installer again. Your other keys stay as they are.
