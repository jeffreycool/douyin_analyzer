#!/bin/bash
# PostToolUse:Edit hook - Run dart analyze on edited files
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[[ ! "$FILE_PATH" =~ \.dart$ ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

LINT_OUTPUT=$(dart analyze "$FILE_PATH" 2>&1 || true)
ERROR_COUNT=$(echo "$LINT_OUTPUT" | grep -c ' - error - ' 2>/dev/null || echo "0")

if [[ "$ERROR_COUNT" -gt 0 ]]; then
  echo "dart analyze found $ERROR_COUNT error(s):" >&2
  echo "$LINT_OUTPUT" | grep ' - error - ' | head -5 >&2
  exit 2
fi

exit 0
