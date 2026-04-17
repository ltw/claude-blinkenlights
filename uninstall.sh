#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/io.ltw.claude-menubar.plist"
HOOKS_DIR="$HOME/.claude/hooks/claude-menubar"
SETTINGS="$HOME/.claude/settings.json"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST" "$HOME/.local/bin/claude-menubar"
rm -rf "$HOOKS_DIR"

[ -f "$SETTINGS" ] && python3 "$(dirname "$0")/sync-hooks.py" "$SETTINGS" "$HOOKS_DIR" uninstall

echo "uninstalled"
