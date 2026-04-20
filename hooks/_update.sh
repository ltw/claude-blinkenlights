#!/usr/bin/env bash
set -euo pipefail

# PPID is the Claude Code process: the hook wrappers (stop.sh etc.) use
# `exec` to replace themselves with this script, so our parent is whatever
# invoked the wrapper.
STATE_DIR="$HOME/.claude/state/sessions"
mkdir -p "$STATE_DIR"

INPUT="$(cat || true)"
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty'        2>/dev/null || true)
[ -z "$SID" ] && SID="${CLAUDE_SESSION_ID:-unknown-$$}"
[ -z "$CWD" ] && CWD="$PWD"

FILE="$STATE_DIR/${SID}.json"

if [ "${CMB_CLEAR:-0}" = "1" ]; then
  rm -f "$FILE"
  exit 0
fi

TMP="$FILE.tmp.$$"
jq -n \
  --arg  sid   "$SID" \
  --arg  cwd   "$CWD" \
  --arg  state "${1:?state required}" \
  --argjson pid "$PPID" \
  --argjson now "$(date +%s)" \
  '{session_id:$sid, cwd:$cwd, pid:$pid, state:$state, last_activity:$now}' > "$TMP"
mv "$TMP" "$FILE"
