# claude-blinkenlights

macOS menu bar activity light for Claude Code. Like the LED on an old disk drive: green means the head is moving, grey means idle.

Two states:
- **active** (green, with count): at least one Claude Code session is currently responding to a prompt (between `UserPromptSubmit` and `Stop`/`SessionEnd`).
- **idle** (grey): nothing is working on anything. Go kick off a prompt.

Goal: keep Claude doing something most of the time. Grey = your cue.

## How it works

Three Claude Code hooks (`UserPromptSubmit`, `Stop`, `SessionEnd`) write per-session JSON to `~/.claude/state/sessions/<session_id>.json`. A Swift `NSStatusBar` app polls that directory once per second and counts sessions whose last event was a prompt rather than a Stop. Stale entries (owning process gone, or last activity older than 10 minutes) are pruned.

The app bundles the hook scripts as resources and installs them into `~/.claude/` on first launch. Claude Code picks them up via entries merged into `~/.claude/settings.json`.

## Prerequisites

- macOS 13 or newer
- Xcode or the Swift 5.9+ toolchain (build time)
- [`jq`](https://jqlang.github.io/jq/) at runtime, used by the hook scripts (`brew install jq`)

## Install

Download the latest `ClaudeBlinkenlights-*.dmg` from [Releases](../../releases). Universal (arm64 + x86_64), ad-hoc signed.

1. Open the `.dmg` and drag `ClaudeBlinkenlights.app` onto the `Applications` shortcut.
2. Launch it from `/Applications`. Gatekeeper will block it on first open because the build isn't notarized; right-click the app → **Open** → **Open**, or run:

   ```bash
   xattr -dr com.apple.quarantine /Applications/ClaudeBlinkenlights.app
   ```

## Build from source

```bash
./build.sh
```

Produces `ClaudeBlinkenlights.app` in the repo root. Drag it to `/Applications` and launch it. On first run it:

1. Copies hook scripts to `~/.claude/hooks/claude-blinkenlights/`
2. Merges hook entries into `~/.claude/settings.json` (idempotent)

To start at login, open the menu and toggle **Open at Login**.

macOS Gatekeeper may refuse to open a locally-built app. If it does, right-click the `.app` in Finder and choose **Open**, or run `xattr -dr com.apple.quarantine ClaudeBlinkenlights.app`.

## Uninstall

1. Menu → **Remove Claude hooks** (strips entries from `settings.json` and deletes `~/.claude/hooks/claude-blinkenlights/`).
2. Menu → **Quit**, then move `ClaudeBlinkenlights.app` to the Trash.

## Development

```bash
swift build           # debug build of the binary alone
swift test            # requires full Xcode (XCTest is not in Command Line Tools)
./build.sh            # assemble ClaudeBlinkenlights.app
```

CI runs `swift build`, `swift test`, and verifies the bundle layout on `macos-14`.

## Layout

```
Package.swift
Info.plist                                    # app bundle metadata
build.sh                                      # assembles ClaudeBlinkenlights.app
hooks/                                        # bash scripts Claude Code invokes
Sources/ClaudeBlinkenlightsCore/              # testable logic (hook install, session parsing)
Sources/ClaudeBlinkenlights/                  # AppKit entry point
Tests/ClaudeBlinkenlightsCoreTests/
.github/workflows/ci.yml
```

## Caveats

- "Thinking" is inferred from session liveness, not from actual LLM streaming. If Claude takes 40s to produce its first tool call, that whole window shows as active, which is what you want.
- If Claude Code is killed mid-session (no `Stop` / `SessionEnd` fires), the state file lingers until the poller notices the pid is gone or the 10-minute activeness window expires.
- Hooks run synchronously; each adds a small `jq` invocation. For high-churn sessions, port `_update.sh` to a compiled language.

## License

MIT. See [LICENSE](LICENSE).
