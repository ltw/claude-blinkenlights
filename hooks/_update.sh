#!/usr/bin/env bash
# Shared helper: read hook JSON from stdin, update ~/.claude/state/sessions/<id>.json
# Args: <new_state>  (working|thinking|idle)
# Optional env: CMB_TOOL, CMB_CLEAR=1 (remove file)

set -u

NEW_STATE="${1:-thinking}"
STATE_DIR="$HOME/.claude/state/sessions"
mkdir -p "$STATE_DIR"

INPUT="$(cat || true)"

SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
[ -z "$SID" ] && SID="${CLAUDE_SESSION_ID:-unknown-$$}"
[ -z "$CWD" ] && CWD="$PWD"
[ -n "${CMB_TOOL:-}" ] && TOOL="$CMB_TOOL"

FILE="$STATE_DIR/${SID}.json"

if [ "${CMB_CLEAR:-0}" = "1" ]; then
  rm -f "$FILE"
  exit 0
fi

NOW=$(date +%s)
PPID_VAL="$PPID"
STARTED="$NOW"
if [ -f "$FILE" ]; then
  STARTED=$(jq -r '.started // empty' "$FILE" 2>/dev/null)
  [ -z "$STARTED" ] && STARTED="$NOW"
fi

TMP="$FILE.tmp.$$"
jq -n \
  --arg sid "$SID" \
  --arg cwd "$CWD" \
  --arg state "$NEW_STATE" \
  --arg tool "$TOOL" \
  --argjson pid "$PPID_VAL" \
  --argjson now "$NOW" \
  --argjson started "$STARTED" \
  '{session_id:$sid, cwd:$cwd, pid:$pid, state:$state,
    tool:(if $tool=="" then null else $tool end),
    last_activity:$now, started:$started}' > "$TMP"
mv "$TMP" "$FILE"

exit 0
