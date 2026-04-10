#!/usr/bin/env bash
# .claude/scripts/gen-stack-rules.sh
#
# Reads KEY=value pairs from stdin (output of detect.sh) and prints
# the appropriate stack-specific rules as a Markdown block on stdout.
#
# Usage:
#   bash .claude/scripts/detect.sh | bash .claude/scripts/gen-stack-rules.sh
#
# The output is inserted into the ## Stack-Specific Rules section
# of .claude/CLAUDE.md by init.sh.

set -euo pipefail

declare -A V
while IFS='=' read -r key val; do
  [[ -z "$key" || "$key" == \#* ]] && continue
  V["$key"]="$val"
done

LANG="${V[LANGUAGE]:-~}"
FRAMEWORK="${V[TEST_FRAMEWORK]:-~}"
TEST_CMD="${V[TEST_COMMAND]:-~}"
TEST_PATHS="${V[TEST_PATHS]:-~}"
PREVIEW="${V[PREVIEW_URL_PATTERN]:-~}"
WINDOWS="${V[WINDOWS_PROJECT]:-false}"

# ── Node / TypeScript ─────────────────────────────────────────────────────────

if echo "$LANG" | grep -qi 'typescript\|javascript'; then
  cat <<RULES
### Node / TypeScript

- Environment variables must be declared before use; assert non-empty at startup — never call a client with empty credentials
RULES

  if [ "${V[PACKAGE_MANAGER]:-~}" != "~" ]; then
    echo "- Package manager: \`${V[PACKAGE_MANAGER]}\` — use it consistently, do not mix with others"
  fi

  if echo "$FRAMEWORK" | grep -qi 'playwright'; then
    cat <<RULES
- Test framework: Playwright — add tests for every new route or component
- Tests live in \`${TEST_PATHS}\`; run with: \`${TEST_CMD}\`
RULES
    if [ "$PREVIEW" != "~" ]; then
      echo "- Playwright runs against preview URL in CI: \`${PREVIEW}\` — do not run against live site from Claude cloud container (HTTPS proxy blocks Chromium)"
    fi
  elif echo "$FRAMEWORK" | grep -qi 'vitest\|jest'; then
    echo "- Test framework: ${FRAMEWORK} — tests in \`${TEST_PATHS}\`; run with: \`${TEST_CMD}\`"
  fi
fi

# ── Godot 4 / GDScript ────────────────────────────────────────────────────────

if echo "$LANG" | grep -qi 'gdscript\|godot'; then
  cat <<'RULES'
### Godot 4 / GDScript

- Godot 4 latest stable only — never generate Godot 3 syntax, class names, or deprecated APIs
- GDScript only — never introduce C# unless explicitly requested in writing
- Static typing required on all function signatures (`: Type` annotations, no implicit types)
- All scene changes must use `call_deferred()`:
  `get_tree().change_scene_to_file.call_deferred(path)` — calling directly silently fails in exported builds when triggered from a signal handler
- All audio routed through `AudioManager` autoload — never call `.play()` directly from gameplay scripts
- Signals for cross-scene communication — never use `get_node()` or `$Path` across scene boundaries
- `@onready` for all node references — never resolve paths in `_process` or repeated calls
- Enums for state machines — never bare integer constants
RULES

  if echo "$FRAMEWORK" | grep -qi 'gut'; then
    echo "- Test framework: GUT — run with: \`${TEST_CMD}\`"
    echo "- Every \`push_error()\` and \`push_warning()\` site must be covered by a GUT test"
  fi
fi

# ── Python ────────────────────────────────────────────────────────────────────

if echo "$LANG" | grep -qi 'python'; then
  PY_CMD="${V[PY_CMD]:-py}"
  VENV_PYTHON=".venv/Scripts/python.exe"

  echo "### Python"
  echo ""
  echo "- Python command: \`${PY_CMD}\` (detected) — always use this, not \`python\` or \`python3\`"
  echo "- Virtual env invocation: \`${VENV_PYTHON}\` for direct calls; never assume venv is activated"
  echo "- Type annotations required on all public function signatures (PEP 484)"
  echo "- Tests in \`${TEST_PATHS}\`; run with: \`${TEST_CMD}\`"
  echo "- Use pytest fixtures for shared setup — never duplicate setup code across test files"
  echo "- config.toml (or equivalent) must be gitignored — always provide a \`.example\` template"

  if [ "$WINDOWS" = "true" ]; then
    cat <<'RULES'

### Windows / System Integration

- Task Scheduler installs require an Administrator terminal — Claude cannot elevate itself;
  provide the exact command for the user to copy-paste
- After modifying `task_scheduler.py`: reinstall required (End → install → Run) — running tasks do not reload their XML config
- System tray icon requires `InteractiveToken` in Task Scheduler XML — without it the process runs in session 0, invisible to the user
- RDP sessions: tray icon is invisible when session is disconnected (not logged off) — this is expected behaviour
- Windows Credential Manager via `keyring` — never store passwords in config files or env vars
- Read logs with: `powershell -Command "Get-Content logs\sync.log -Tail 30"` — never use `tail`
- If `ADMIN.md` exists: read it at session start; point users to it for all elevated commands
RULES
  fi
fi

# ── Fallback: nothing detected ────────────────────────────────────────────────

if [ "$LANG" = "~" ]; then
  echo "### Stack not detected"
  echo ""
  echo "Run \`/init-project\` or \`bash .claude/scripts/detect.sh\` to detect the stack."
  echo "Then run \`bash .claude/scripts/init.sh\` to populate this section."
fi
