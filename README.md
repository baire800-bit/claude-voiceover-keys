# Claude VoiceOver keys

Keyboard shortcuts that make the Claude desktop app on macOS quicker to use with VoiceOver. Hold your VoiceOver Option key and press a letter to jump straight to part of the app, or to have VoiceOver tell you something without hunting for it.

The keys use VoiceOver's Option Key commands. In VoiceOver Utility, under Commands, you choose which Option key they listen to: Right Option, Left Option, or either. Wherever this guide says "Option", use whichever you've set.

## The keys

All of these are your VoiceOver Option key plus a letter.

- P: move to the message box.
- B: move to the session you're in, in the sidebar.
- C: move to the Chat and Cowork / Code buttons.
- O: move to Routines.
- L: listen to Claude's latest reply.
- W: hear all your sessions, grouped: waiting for you first, then running, then idle.
- I: hear this session's model, effort, permission mode and usage.
- H: hear which session you're in, and its folder.
- R: start dictation, and press again to stop. On the first press VoiceOver goes quiet, you hear three beeps, and recording starts after the third, so VoiceOver doesn't talk over you or get typed into your message. On the second press, recording stops and VoiceOver says "Stopped".

If one of these letters is already assigned to something else in your Option key commands, the installer leaves it alone and tells you which ones it skipped.

## Before you install

The installer changes settings on your Mac. It adds scripts to your Library, writes the keys into VoiceOver's settings, and switches on two VoiceOver settings the keys need. It also asks you for two permissions: Full Disk Access for Terminal while it runs, and Accessibility for the claudevo tool. It backs up VoiceOver's settings before changing them, and uninstall.sh removes everything it added. It's offered as is, with no warranty, as the licence says. If you'd like to see exactly what it does first, read install.sh, or run it with --dry-run, which changes nothing.

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

1. It builds the claudevo tool and installs the VoiceOver scripts. This takes about a minute.
2. VoiceOver keeps its settings in a protected part of the Library, so Terminal needs Full Disk Access to assign the keys. If Terminal doesn't have it yet, the installer opens Privacy and Security, Full Disk Access and stops. Switch Terminal on, and choose Quit & Reopen when macOS asks. Then run the installer again: open Install.command again, or paste the one-line command again. The second run takes a few seconds, because the rest is already done.
3. It assigns the nine keys and lists them. It also switches on "Allow VoiceOver to be controlled with AppleScript" and VoiceOver's Option key commands, if they're off.
4. Turn VoiceOver off and on again with Command-F5, twice, so it picks up the new keys.
5. The first time you press one of the keys, macOS asks whether claudevo may use accessibility features. Choose Open System Settings, switch on claudevo in Privacy and Security, Accessibility, then press the key again.

You can switch Terminal's Full Disk Access off again once the installer has finished. The keys stay.

To see what the installer would do without changing anything, run it in Terminal with --dry-run: bash install.sh --dry-run

## Uninstalling

In Terminal, go to this folder and run: bash uninstall.sh

It removes only the keys and files this installer added, and keeps your VoiceOver settings backups. Like the installer, it needs Terminal to have Full Disk Access to remove the keys from VoiceOver's settings, and it tells you if that's missing. Afterwards, turn VoiceOver off and on again.

## Good to know

- The keys find things in the Claude app by their accessibility labels, such as "Prompt" and "Press and hold to record". If an app update renames one, that key stops working until this is updated.
- Because of that, the keys only work with the Claude app in English.
- Running the installer again only rebuilds claudevo when its source code has changed. A rebuild can make macOS forget claudevo's Accessibility permission. If a key says it needs permission, switch claudevo off and on again in Privacy and Security, Accessibility.
- Nothing here types for you or opens other apps. The tool uses the macOS accessibility interface to move focus and read labels, and VoiceOver's own scripting to speak.

## What's in this folder

- install.sh: the installer.
- Install.command: open this from Finder (Command-Down Arrow) to run the installer.
- uninstall.sh: removes everything the installer added.
- src/claudevo.swift: the tool's source code.
- scripts: templates for the VoiceOver scripts the installer creates.

## Feedback

Found a problem, or have an idea for another key? Please open an issue on this project's Issues page: https://github.com/baire800-bit/claude-voiceover-keys/issues

It helps to say which key you pressed, what VoiceOver said, and which version of macOS you're using.
