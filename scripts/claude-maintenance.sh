#!/bin/bash
# Claude Code configuration maintenance script
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MEMORY_DIR="$HOME/.claude/projects/-Users-jeffrey-douyin_analyzer/memory"

echo "=== Claude Code Maintenance: $(date) ==="
echo "Project: $PROJECT_DIR"
echo ""

# 1. Check .claudeignore
if [[ -f "$PROJECT_DIR/.claudeignore" ]]; then
  LINES=$(wc -l < "$PROJECT_DIR/.claudeignore")
  echo "✅ .claudeignore: $LINES lines"
else
  echo "❌ .claudeignore: MISSING"
fi

# 2. Check hooks
HOOKS_DIR="$PROJECT_DIR/.claude/hooks"
if [[ -d "$HOOKS_DIR" ]]; then
  HOOK_COUNT=$(find "$HOOKS_DIR" -name "*.sh" -perm +111 | wc -l | tr -d ' ')
  echo "✅ Hooks: $HOOK_COUNT executable scripts"
else
  echo "❌ Hooks directory: MISSING"
fi

# 3. Check settings.json validity
SETTINGS="$PROJECT_DIR/.claude/settings.json"
if [[ -f "$SETTINGS" ]]; then
  if python3 -c "import json; json.load(open('$SETTINGS'))" 2>/dev/null; then
    echo "✅ settings.json: valid JSON"
  else
    echo "❌ settings.json: INVALID JSON"
  fi
else
  echo "⚠️ settings.json: not found"
fi

# 4. Check CLAUDE.md line counts
if [[ -f "$PROJECT_DIR/CLAUDE.md" ]]; then
  LINES=$(wc -l < "$PROJECT_DIR/CLAUDE.md" | tr -d ' ')
  if [[ $LINES -gt 200 ]]; then
    echo "⚠️ CLAUDE.md: $LINES lines (recommend < 200)"
  else
    echo "✅ CLAUDE.md: $LINES lines"
  fi
else
  echo "❌ CLAUDE.md: MISSING"
fi

# 5. Check Memory files
if [[ -f "$MEMORY_DIR/MEMORY.md" ]]; then
  LINES=$(wc -l < "$MEMORY_DIR/MEMORY.md" | tr -d ' ')
  echo "✅ MEMORY.md: $LINES lines"
  if [[ $LINES -gt 200 ]]; then
    echo "⚠️ MEMORY.md exceeds 200 lines — will be truncated!"
  fi
else
  echo "❌ Memory files: MISSING"
fi

# 6. Check external tools
echo ""
echo "--- External Tools ---"
for tool in /opt/homebrew/bin/ffmpeg /opt/homebrew/bin/whisper-cli "$HOME/.local/bin/claude"; do
  if [[ -x "$tool" ]]; then
    echo "✅ $(basename "$tool"): $tool"
  else
    echo "❌ $(basename "$tool"): NOT FOUND at $tool"
  fi
done

echo ""
echo "=== Maintenance complete ==="
