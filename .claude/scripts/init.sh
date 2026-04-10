#!/usr/bin/env bash
# .claude/scripts/init.sh
#
# Master init script. Chains detect → fill-manifest → gen-stack-rules.
# This is what /init-project tells Claude to run.
#
# Usage:
#   bash .claude/scripts/init.sh
#   FORCE=1 bash .claude/scripts/init.sh   # re-detect and overwrite all fields
#
# What it does:
#   1. Runs detect.sh — inspects files, outputs KEY=value pairs
#   2. Runs fill-manifest.sh — writes values into .claude/CLAUDE.md YAML block
#   3. Runs gen-stack-rules.sh — generates stack-specific rules markdown
#   4. Inserts the rules into the ## Stack-Specific Rules section
#   5. Prints a summary for Claude to confirm
#
# After this script runs, Claude should:
#   - Read .claude/CLAUDE.md to see the filled manifest
#   - Check the UNKNOWN_FIELDS list at the end and ask the user only for those
#   - Commit .claude/CLAUDE.md

set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
SCRIPTS="$ROOT/.claude/scripts"
TARGET="$ROOT/.claude/CLAUDE.md"
FORCE="${FORCE:-0}"

echo "[init] Detecting project stack in: $ROOT"
echo ""

# ── Step 1: Detect ────────────────────────────────────────────────────────────

DETECTED=$(bash "$SCRIPTS/detect.sh" 2>/dev/null)
echo "$DETECTED"
echo ""

# ── Step 2: Fill manifest ─────────────────────────────────────────────────────

echo "[init] Writing manifest…"
echo "$DETECTED" | FORCE="$FORCE" bash "$SCRIPTS/fill-manifest.sh"
echo ""

# ── Step 3: Generate and insert stack-specific rules ─────────────────────────

echo "[init] Generating stack-specific rules…"
RULES=$(echo "$DETECTED" | bash "$SCRIPTS/gen-stack-rules.sh")

# Insert rules into the ## Stack-Specific Rules section
# Replaces everything between the placeholder comment and the next ## heading
if grep -q 'STACK_RULES_PLACEHOLDER' "$TARGET"; then
  awk -v rules="$RULES" '
    /<!-- STACK_RULES_PLACEHOLDER -->/ {
      print rules
      skip=1
      next
    }
    skip && /^## / { skip=0 }
    !skip { print }
  ' "$TARGET" > "${TARGET}.tmp" && mv "${TARGET}.tmp" "$TARGET"
  echo "[init] Stack-specific rules inserted."
else
  # Section already populated — only overwrite if FORCE=1
  if [ "$FORCE" = "1" ]; then
    awk -v rules="$RULES" '
      /^## Stack-Specific Rules/ {
        print
        print ""
        print rules
        skip=1
        next
      }
      skip && /^## / && !/^## Stack-Specific Rules/ { skip=0 }
      !skip { print }
    ' "$TARGET" > "${TARGET}.tmp" && mv "${TARGET}.tmp" "$TARGET"
    echo "[init] Stack-specific rules replaced (FORCE=1)."
  else
    echo "[init] Stack-Specific Rules already populated. Use FORCE=1 to overwrite."
  fi
fi

# ── Step 4: Report unknowns ───────────────────────────────────────────────────

echo ""
echo "[init] Unknown fields (need user input):"
UNKNOWNS=0
while IFS='=' read -r key val; do
  [[ -z "$key" || "$key" == \#* ]] && continue
  if [ "$val" = "~" ]; then
    echo "  - $key"
    UNKNOWNS=$((UNKNOWNS + 1))
  fi
done <<< "$DETECTED"

if [ "$UNKNOWNS" -eq 0 ]; then
  echo "  none — manifest fully populated"
fi

# ── Step 5: Final status ──────────────────────────────────────────────────────

echo ""
echo "[init] Done. Manifest status:"
grep '^status:\|^name:\|^language:\|^test_framework:\|^deploy_platform:\|^branch_base:' "$TARGET"
echo ""
echo "[init] Next steps for Claude:"
echo "  1. Read .claude/CLAUDE.md to verify the manifest"
[ "$UNKNOWNS" -gt 0 ] && echo "  2. Ask the user to clarify the $UNKNOWNS unknown field(s) above"
echo "  3. git add .claude/CLAUDE.md && git commit -m 'chore: initialize Claude Code project manifest'"
