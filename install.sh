#!/usr/bin/env bash
# Installs claude-menubar: builds the Swift app, registers hooks in ~/.claude/settings.json,
# and sets up a LaunchAgent so it runs at login.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$HOME/.local/bin"
HOOKS_DIR="$HOME/.claude/hooks/claude-menubar"
STATE_DIR="$HOME/.claude/state/sessions"
SETTINGS="$HOME/.claude/settings.json"
AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT_PLIST="$AGENT_DIR/io.ltw.claude-menubar.plist"
LABEL="io.ltw.claude-menubar"

echo "==> Building Swift binary"
cd "$REPO_DIR"
swift build -c release
BUILT_BIN="$REPO_DIR/.build/release/ClaudeMenubar"

mkdir -p "$BIN_DIR" "$HOOKS_DIR" "$STATE_DIR" "$AGENT_DIR"

echo "==> Installing binary -> $BIN_DIR/claude-menubar"
cp "$BUILT_BIN" "$BIN_DIR/claude-menubar"
chmod +x "$BIN_DIR/claude-menubar"

echo "==> Installing hook scripts -> $HOOKS_DIR"
cp "$REPO_DIR/hooks/"*.sh "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/"*.sh

echo "==> Merging hooks into $SETTINGS"
python3 "$REPO_DIR/install_settings.py" "$SETTINGS" "$HOOKS_DIR"

echo "==> Writing LaunchAgent -> $AGENT_PLIST"
cat > "$AGENT_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN_DIR/claude-menubar</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$HOME/.claude/state/claude-menubar.log</string>
  <key>StandardErrorPath</key><string>$HOME/.claude/state/claude-menubar.err</string>
</dict>
</plist>
PLIST

if launchctl list | grep -q "$LABEL"; then
  launchctl unload "$AGENT_PLIST" 2>/dev/null || true
fi
launchctl load "$AGENT_PLIST"

echo "==> Done. Menu bar app should appear shortly."
echo "    Logs: ~/.claude/state/claude-menubar.log"
echo "    State: $STATE_DIR"
