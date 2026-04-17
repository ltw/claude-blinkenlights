#!/usr/bin/env python3
import json, sys
from pathlib import Path

settings, hooks_dir, mode = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
assert mode in ("install", "uninstall"), "mode must be install|uninstall"

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
    if not matchers:
        del hooks[ev]

if mode == "install":
    for ev, script in events.items():
        matchers = hooks.setdefault(ev, [])
        block = next((m for m in matchers if m.get("matcher", "") == ""), None)
        if block is None:
            block = {"matcher": "", "hooks": []}
            matchers.append(block)
        block["hooks"].append({"type": "command", "command": f"bash {hooks_dir}/{script}"})

settings.write_text(json.dumps(d, indent=2) + "\n")
