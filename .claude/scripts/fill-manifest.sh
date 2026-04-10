#!/usr/bin/env bash
# .claude/scripts/fill-manifest.sh
#
# Reads KEY=value pairs from stdin (output of detect.sh) and writes
# them into the PROJECT MANIFEST YAML block in .claude/CLAUDE.md.
#
# Usage:
#   bash .claude/scripts/detect.sh | bash .claude/scripts/fill-manifest.sh
#
# The script edits .claude/CLAUDE.md in-place using awk.
# Fields already set (not ~) are left untouched unless FORCE=1 is set.
#
#   FORCE=1 bash .claude/scripts/fill-manifest.sh   # overwrite all fields

set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
TARGET="$ROOT/.claude/CLAUDE.md"

if [ ! -f "$TARGET" ]; then
  echo "ERROR: $TARGET not found" >&2
  exit 1
fi

# Read all KEY=value pairs from stdin into associative array
declare -A VALUES
while IFS='=' read -r key val; do
  [[ -z "$key" || "$key" == \#* ]] && continue
  VALUES["$key"]="$val"
done

FORCE="${FORCE:-0}"

# Map from manifest YAML key → shell KEY from detect.sh
declare -A YAML_TO_KEY=(
  [name]="NAME"
  [description]="DESCRIPTION"
  [language]="LANGUAGE"
  [runtime_version]="RUNTIME_VERSION"
  [package_manager]="PACKAGE_MANAGER"
  [test_framework]="TEST_FRAMEWORK"
  [test_command]="TEST_COMMAND"
  [test_paths]="TEST_PATHS"
  [deploy_platform]="DEPLOY_PLATFORM"
  [production_url]="PRODUCTION_URL"
  [preview_url_pattern]="PREVIEW_URL_PATTERN"
  [branch_base]="BRANCH_BASE"
)

# Build sed substitution commands
SED_ARGS=()
for yaml_key in "${!YAML_TO_KEY[@]}"; do
  shell_key="${YAML_TO_KEY[$yaml_key]}"
  new_val="${VALUES[$shell_key]:-}"
  [ -z "$new_val" ] || [ "$new_val" = "~" ] && continue

  # Only replace lines that are currently ~ (or all if FORCE=1)
  if [ "$FORCE" = "1" ]; then
    SED_ARGS+=(-e "s|^${yaml_key}: .*|${yaml_key}: ${new_val}|")
  else
    SED_ARGS+=(-e "s|^${yaml_key}: ~|${yaml_key}: ${new_val}|")
  fi
done

# Apply substitutions
if [ ${#SED_ARGS[@]} -gt 0 ]; then
  sed -i "${SED_ARGS[@]}" "$TARGET"
fi

# Handle ci_workflows separately (list format)
if [ -n "${VALUES[CI_WORKFLOWS]:-}" ] && [ "${VALUES[CI_WORKFLOWS]}" != "~" ]; then
  # Only fill if currently empty list []
  if grep -q '^ci_workflows: \[\]' "$TARGET"; then
    WORKFLOW_LINES=""
    IFS=';' read -ra ENTRIES <<< "${VALUES[CI_WORKFLOWS]}"
    for entry in "${ENTRIES[@]}"; do
      entry=$(echo "$entry" | sed 's/^[[:space:]]*//')
      [ -z "$entry" ] && continue
      IFS='|' read -r file wf_name trigger <<< "$entry"
      WORKFLOW_LINES="${WORKFLOW_LINES}  - file: ${file}\n    trigger: ${trigger}\n    purpose: ~\n"
    done
    if [ -n "$WORKFLOW_LINES" ]; then
      # Replace the empty list with the populated one
      awk -v wf="$WORKFLOW_LINES" '
        /^ci_workflows: \[\]/ { print "ci_workflows:"; printf wf; next }
        { print }
      ' "$TARGET" > "${TARGET}.tmp" && mv "${TARGET}.tmp" "$TARGET"
    fi
  fi
fi

# Handle companion_reads separately (list format)
if [ -n "${VALUES[COMPANION_READS]:-}" ] && [ "${VALUES[COMPANION_READS]}" != "~" ]; then
  if grep -q '^companion_reads: \[\]' "$TARGET"; then
    COMPANION_LINES=""
    for f in ${VALUES[COMPANION_READS]}; do
      COMPANION_LINES="${COMPANION_LINES}  - ${f}\n"
    done
    awk -v cl="$COMPANION_LINES" '
      /^companion_reads: \[\]/ { print "companion_reads:"; printf cl; next }
      { print }
    ' "$TARGET" > "${TARGET}.tmp" && mv "${TARGET}.tmp" "$TARGET"
  fi
fi

# Set status: complete
sed -i 's/^status: pending/status: complete/' "$TARGET"

echo "Manifest updated: $TARGET"
grep '^status:\|^name:\|^language:\|^test_framework:\|^deploy_platform:' "$TARGET"
