#!/usr/bin/env python3
"""Merge claude-menubar hook commands into ~/.claude/settings.json idempotently.

Usage: install_settings.py <settings_path> <hooks_dir>

Adds entries for the events we care about and removes any stale tagged
entries (e.g. events we previously registered but no longer need).
"""
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
hooks_dir = Path(sys.argv[2])

events = {
    "UserPromptSubmit": hooks_dir / "user-prompt-submit.sh",
    "Stop":             hooks_dir / "stop.sh",
    "SessionEnd":       hooks_dir / "session-end.sh",
}

TAG = "# claude-menubar"

def build_cmd(script: Path) -> str:
    return f"bash {script} {TAG}"

data = json.loads(settings_path.read_text()) if settings_path.exists() else {}
hooks = data.setdefault("hooks", {})

# Strip tagged entries from every event, then re-add only the ones we want.
for event, matchers in list(hooks.items()):
    for m in matchers:
        m["hooks"] = [h for h in m.get("hooks", []) if TAG not in (h.get("command") or "")]
    matchers[:] = [m for m in matchers if m.get("hooks")]
    if not matchers:
        del hooks[event]

for event, script in events.items():
    matchers = hooks.setdefault(event, [])
    block = next((m for m in matchers if m.get("matcher", "") == ""), None)
    if block is None:
        block = {"matcher": "", "hooks": []}
        matchers.append(block)
    block.setdefault("hooks", []).append({"type": "command", "command": build_cmd(script)})

settings_path.write_text(json.dumps(data, indent=2) + "\n")
print(f"updated {settings_path}")
