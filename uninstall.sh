#!/usr/bin/env bash
set -euo pipefail

LABEL="io.ltw.claude-menubar"
AGENT_PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SETTINGS="$HOME/.claude/settings.json"

if [ -f "$AGENT_PLIST" ]; then
  launchctl unload "$AGENT_PLIST" 2>/dev/null || true
  rm -f "$AGENT_PLIST"
fi

rm -f "$HOME/.local/bin/claude-menubar"
rm -rf "$HOME/.claude/hooks/claude-menubar"

if [ -f "$SETTINGS" ]; then
  python3 - "$SETTINGS" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
d = json.loads(p.read_text())
TAG = "# claude-menubar"
for event, matchers in list(d.get("hooks", {}).items()):
    for m in matchers:
        m["hooks"] = [h for h in m.get("hooks", []) if TAG not in (h.get("command") or "")]
    matchers[:] = [m for m in matchers if m.get("hooks")]
    if not matchers:
        del d["hooks"][event]
p.write_text(json.dumps(d, indent=2) + "\n")
print("cleaned", p)
PY
fi

echo "Uninstalled."
