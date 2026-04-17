# claude-menubar

macOS menu bar indicator for Claude Code agent activity.

Two states:
- **active** (green, with count): at least one Claude Code session is currently responding to a prompt (between `UserPromptSubmit` and `Stop`/`SessionEnd`)
- **idle** (grey): nothing is working on anything. Go kick off a prompt.

Goal: keep Claude doing something most of the time. Grey = your cue.

## How it works

Three Claude Code hooks (`UserPromptSubmit`, `Stop`, `SessionEnd`) write per-session JSON to `~/.claude/state/sessions/<session_id>.json`. A tiny Swift `NSStatusBar` app polls that directory once per second and counts sessions whose last event was a prompt rather than a Stop. Stale files (whose owning shell pid is gone, or that are older than 10 minutes) are pruned.

## Install

```bash
./install.sh
```

That will:
1. `swift build -c release` the menu bar binary into `.build/release/ClaudeMenubar`
2. Copy it to `~/.local/bin/claude-menubar`
3. Copy hook scripts to `~/.claude/hooks/claude-menubar/`
4. Merge hook entries into `~/.claude/settings.json` (idempotent, tagged with `# claude-menubar`)
5. Install a LaunchAgent so the app runs at login, and load it now.

## Uninstall

```bash
./uninstall.sh
```

Removes the binary, hooks, LaunchAgent, and strips tagged hook entries from `settings.json`.

## Layout

```
Package.swift
Sources/ClaudeMenubar/main.swift   # the menu bar app
hooks/                              # bash scripts Claude Code invokes
install.sh                          # build + wire everything up
install_settings.py                 # idempotent settings.json merge
uninstall.sh
```

## Caveats

- "Thinking" is inferred from session liveness, not from actual LLM streaming. If Claude takes 40s to produce its first tool call, that whole window shows as thinking — which is what you want.
- If Claude Code is killed mid-session (no `Stop` / `SessionEnd` fires), the state file lingers. The app prunes entries whose pid (PPID of the hook process) is gone.
- Hooks run synchronously; each adds ~10ms of `jq` overhead per tool call. If that matters, rewrite `_update.sh` in a compiled language.
