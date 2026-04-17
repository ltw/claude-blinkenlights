#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

BIN="$HOME/.local/bin/claude-menubar"
HOOKS_DIR="$HOME/.claude/hooks/claude-menubar"
SETTINGS="$HOME/.claude/settings.json"
PLIST="$HOME/Library/LaunchAgents/io.ltw.claude-menubar.plist"

swift build -c release
mkdir -p "$(dirname "$BIN")" "$HOOKS_DIR"
cp .build/release/ClaudeMenubar "$BIN"
cp hooks/*.sh "$HOOKS_DIR/"

python3 sync-hooks.py "$SETTINGS" "$HOOKS_DIR" install

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>io.ltw.claude-menubar</string>
  <key>ProgramArguments</key><array><string>$BIN</string></array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/.claude/state/claude-menubar.log</string>
  <key>StandardErrorPath</key><string>$HOME/.claude/state/claude-menubar.err</string>
</dict></plist>
PLIST

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load "$PLIST"
echo "installed"
