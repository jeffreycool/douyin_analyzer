#!/bin/bash
# PreToolUse:Bash hook - Command safety check
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$COMMAND" ]] && exit 0

# Block dangerous commands
if echo "$COMMAND" | grep -qE '^rm -rf /|^sudo rm|git push.*--force.*(main|master)'; then
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked dangerous command: potential data loss or force push to protected branch."}}
EOF
  exit 0
fi

exit 0
