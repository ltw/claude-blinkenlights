#!/usr/bin/env python3
import json, sys
from pathlib import Path

settings_path, hooks_dir, mode = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
assert mode in ("install", "uninstall"), "mode must be install|uninstall"

events = {
    "UserPromptSubmit": "user-prompt-submit.sh",
    "Stop":             "stop.sh",
    "SessionEnd":       "session-end.sh",
}

config = json.loads(settings_path.read_text()) if settings_path.exists() else {}
hook_config = config.setdefault("hooks", {})

def is_ours(handler):
    return hooks_dir in (handler.get("command") or "")

for event, matcher_blocks in list(hook_config.items()):
    for block in matcher_blocks:
        block["hooks"] = [h for h in block.get("hooks", []) if not is_ours(h)]
    matcher_blocks[:] = [b for b in matcher_blocks if b.get("hooks")]
    if not matcher_blocks:
        del hook_config[event]

if mode == "install":
    for event, script in events.items():
        matcher_blocks = hook_config.setdefault(event, [])
        default_block = next((b for b in matcher_blocks if b.get("matcher", "") == ""), None)
        if default_block is None:
            default_block = {"matcher": "", "hooks": []}
            matcher_blocks.append(default_block)
        default_block["hooks"].append({
            "type": "command",
            "command": f"bash {hooks_dir}/{script}",
        })

settings_path.write_text(json.dumps(config, indent=2) + "\n")
