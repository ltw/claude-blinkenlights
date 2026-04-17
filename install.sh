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

python3 - "$SETTINGS" "$HOOKS_DIR" <<'PY'
import json, sys
from pathlib import Path
settings, hooks_dir = Path(sys.argv[1]), sys.argv[2]
events = {
    "UserPromptSubmit": "user-prompt-submit.sh",
    "Stop":             "stop.sh",
    "SessionEnd":       "session-end.sh",
}
d = json.loads(settings.read_text()) if settings.exists() else {}
hooks = d.setdefault("hooks", {})
for ev, matchers in list(hooks.items()):
    for m in matchers:
        m["hooks"] = [h for h in m.get("hooks", []) if hooks_dir not in (h.get("command") or "")]
    matchers[:] = [m for m in matchers if m.get("hooks")]
    if not matchers: del hooks[ev]
for ev, script in events.items():
    matchers = hooks.setdefault(ev, [])
    block = next((m for m in matchers if m.get("matcher", "") == ""), None)
    if block is None:
        block = {"matcher": "", "hooks": []}
        matchers.append(block)
    block["hooks"].append({"type": "command", "command": f"bash {hooks_dir}/{script}"})
settings.write_text(json.dumps(d, indent=2) + "\n")
PY

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
