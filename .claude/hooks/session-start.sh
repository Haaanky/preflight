#!/usr/bin/env bash
# .claude/hooks/session-start.sh
# Runs automatically when Claude Code opens a session in this project.
# The Claude Code harness executes this — Claude itself does not run it.
#
# Output is shown to Claude as part of session context.
# Keep it fast (< 1s) and informative — no heavy commands here.

set -euo pipefail

CLAUDE_MD="$CLAUDE_PROJECT_DIR/.claude/CLAUDE.md"

# ── 1. Check manifest status ──────────────────────────────────────────────────

MANIFEST_STATUS=$(grep -m1 '^status:' "$CLAUDE_MD" 2>/dev/null | awk '{print $2}' || echo "missing")

if [ "$MANIFEST_STATUS" = "pending" ] || [ "$MANIFEST_STATUS" = "missing" ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║  PROJECT MANIFEST IS INCOMPLETE                              ║"
  echo "║  Run: bash .claude/scripts/init.sh                           ║"
  echo "║  Or invoke /init-project — it runs the script for you.       ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  # Pre-flight: run detect.sh and print the raw output so Claude sees it
  # immediately without needing to run a separate command
  DETECT_SCRIPT="$CLAUDE_PROJECT_DIR/.claude/scripts/detect.sh"
  if [ -f "$DETECT_SCRIPT" ]; then
    echo "--- Pre-flight detection (run init.sh to apply) ---"
    bash "$DETECT_SCRIPT" 2>/dev/null || true
    echo "---------------------------------------------------"
  fi
  echo ""
  exit 0
fi

# ── 2. Print manifest summary for AI context ──────────────────────────────────

echo ""
echo "━━━ SESSION START — $(basename "$CLAUDE_PROJECT_DIR") ━━━"
echo ""

# Extract key fields from the YAML manifest block
extract() {
  grep -m1 "^$1:" "$CLAUDE_MD" 2>/dev/null | sed "s/^$1:[[:space:]]*//" | tr -d "'" || echo "~"
}

NAME=$(extract name)
LANG=$(extract language)
VERSION=$(extract runtime_version)
PKG=$(extract package_manager)
TEST_FW=$(extract test_framework)
TEST_CMD=$(extract test_command)
DEPLOY=$(extract deploy_platform)
PROD_URL=$(extract production_url)
PREVIEW=$(extract preview_url_pattern)
BRANCH=$(extract branch_base)

echo "  Project   : $NAME"
echo "  Stack     : $LANG $VERSION  |  $PKG"
echo "  Tests     : $TEST_FW  →  $TEST_CMD"
echo "  Deploy    : $DEPLOY"
[ "$PROD_URL" != "~" ] && echo "  Prod URL  : $PROD_URL"
[ "$PREVIEW"  != "~" ] && echo "  Preview   : $PREVIEW"
echo "  Base branch: $BRANCH"

# ── 3. Print companion reads ───────────────────────────────────────────────────

COMPANIONS=$(awk '/^companion_reads:/,/^[^ ]/' "$CLAUDE_MD" 2>/dev/null \
  | grep '^\s*-' | sed 's/.*- //' | tr -d '~' | grep -v '^$' || true)

if [ -n "$COMPANIONS" ]; then
  echo ""
  echo "  Mandatory reads this session:"
  echo "$COMPANIONS" | while IFS= read -r f; do
    echo "    • $f"
  done
fi

# ── 4. Print known limitations ─────────────────────────────────────────────────

LIMITS=$(awk '/^known_limitations:/,/^[^ ]/' "$CLAUDE_MD" 2>/dev/null \
  | grep '^\s*-' | sed 's/.*- //' | tr -d '~' | grep -v '^$' || true)

if [ -n "$LIMITS" ]; then
  echo ""
  echo "  Known limitations:"
  echo "$LIMITS" | while IFS= read -r l; do
    echo "    ⚠ $l"
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
