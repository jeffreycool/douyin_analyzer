#!/bin/bash
# PostToolUse:Write hook - Check newly created Dart files
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only check Dart files
[[ ! "$FILE_PATH" =~ \.dart$ ]] && exit 0

FILENAME=$(basename "$FILE_PATH")

# Check file naming: snake_case convention
if [[ ! "$FILENAME" =~ ^[a-z][a-z0-9_]*\.dart$ ]]; then
  echo "File name '$FILENAME' does not follow snake_case convention." >&2
  echo "Expected pattern: lowercase_with_underscores.dart" >&2
  exit 2
fi

exit 0
