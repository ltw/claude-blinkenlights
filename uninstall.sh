#!/usr/bin/env bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/io.ltw.claude-menubar.plist"
HOOKS_DIR="$HOME/.claude/hooks/claude-menubar"
SETTINGS="$HOME/.claude/settings.json"

launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST" "$HOME/.local/bin/claude-menubar"
rm -rf "$HOOKS_DIR"

[ -f "$SETTINGS" ] && python3 - "$SETTINGS" "$HOOKS_DIR" <<'PY'
import json, sys
from pathlib import Path
settings, hooks_dir = Path(sys.argv[1]), sys.argv[2]
d = json.loads(settings.read_text())
hooks = d.get("hooks", {})
for ev, matchers in list(hooks.items()):
    for m in matchers:
        m["hooks"] = [h for h in m.get("hooks", []) if hooks_dir not in (h.get("command") or "")]
    matchers[:] = [m for m in matchers if m.get("hooks")]
    if not matchers: del hooks[ev]
settings.write_text(json.dumps(d, indent=2) + "\n")
PY

echo "uninstalled"
