#!/bin/bash
set -e

PLUGIN_ID="org.kde.plasma.kickoff-simplified"
INSTALL_DIR="${HOME}/.local/share/plasma/plasmoids/${PLUGIN_ID}"

# Remove old installation if present
kpackagetool6 --type Plasma/Applet --remove "$PLUGIN_ID" 2>/dev/null || true
# Force-remove leftover directory if kpackagetool6 failed to clean it
[ -d "$INSTALL_DIR" ] && rm -rf "$INSTALL_DIR"

kpackagetool6 --type Plasma/Applet --install package/

# Clear plasmashell compiled QML/JS bytecode cache
rm -rf ~/.cache/plasmashell/qmlcache

# Restart plasmashell to apply
plasmashell --replace & disown
