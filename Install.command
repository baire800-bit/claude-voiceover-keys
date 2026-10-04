#!/bin/bash
# Open this to install (in Finder, select it and press Command-Down Arrow). The first time, macOS blocks it
# because it is not signed: allow it in System Settings, Privacy & Security, Open Anyway. See the README.
cd "$(dirname "$0")" && bash ./install.sh
echo; read -r -p "Press Return to close this window."
