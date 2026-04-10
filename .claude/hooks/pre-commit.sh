#!/usr/bin/env bash
# .claude/hooks/pre-commit.sh
# Runs before every `git commit` call Claude makes.
# Exit non-zero to abort the commit and surface the error to Claude.
#
# The harness executes this — Claude does not run it directly.
# Replace the test command below with your project's runner.

set -euo pipefail

CLAUDE_MD="$CLAUDE_PROJECT_DIR/.claude/CLAUDE.md"

# Read test command from manifest
TEST_CMD=$(grep -m1 '^test_command:' "$CLAUDE_MD" 2>/dev/null \
  | sed 's/^test_command:[[:space:]]*//' | tr -d "'" || echo "")

if [ -z "$TEST_CMD" ] || [ "$TEST_CMD" = "~" ]; then
  # Manifest not filled yet — fall back to npm test if available
  TEST_CMD="npm test --if-present"
fi

echo "[pre-commit] Running: $TEST_CMD"
eval "$TEST_CMD"
