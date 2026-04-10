#!/usr/bin/env bash
# .claude/scripts/detect.sh
#
# Detects project stack and outputs KEY=value pairs on stdout.
# Claude reads this output instead of inspecting files manually.
#
# Usage:
#   bash .claude/scripts/detect.sh
#   bash .claude/scripts/detect.sh 2>/dev/null   # suppress warnings
#
# Output format: one KEY=value per line, values never contain newlines.
# Unknown values are output as KEY=~
#
# Token-saving principle: run this script first — don't read individual
# files to compute what this script already tells you.

set -euo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$ROOT"

emit() { printf '%s=%s\n' "$1" "$2"; }

# ── Identity ──────────────────────────────────────────────────────────────────

NAME="~"
if [ -f package.json ] && command -v jq &>/dev/null; then
  NAME=$(jq -r '.name // empty' package.json 2>/dev/null || echo "~")
fi
if [ "$NAME" = "~" ] && [ -f project.godot ]; then
  NAME=$(grep -m1 'config/name' project.godot | sed 's/.*= "//;s/"//' 2>/dev/null || echo "~")
fi
[ "$NAME" = "~" ] && NAME=$(basename "$ROOT")
emit NAME "$NAME"

DESCRIPTION="~"
if [ -f package.json ] && command -v jq &>/dev/null; then
  DESCRIPTION=$(jq -r '.description // empty' package.json 2>/dev/null || echo "~")
fi
if [ "$DESCRIPTION" = "~" ] && [ -f README.md ]; then
  # Second non-empty line of README, strip markdown heading markers
  DESCRIPTION=$(grep -v '^\s*$' README.md | sed -n '2p' | sed 's/^#\+\s*//' 2>/dev/null || echo "~")
fi
emit DESCRIPTION "$DESCRIPTION"

# ── Language & runtime ────────────────────────────────────────────────────────

LANGUAGE="~"
RUNTIME_VERSION="~"

if [ -f package.json ]; then
  LANGUAGE="TypeScript/JavaScript"
  RUNTIME_VERSION=$(node --version 2>/dev/null || echo "~")
elif [ -f project.godot ]; then
  LANGUAGE="GDScript"
  RUNTIME_VERSION=$(godot --version 2>/dev/null | head -1 || echo "~")
elif [ -f Cargo.toml ]; then
  LANGUAGE="Rust"
  RUNTIME_VERSION=$(rustc --version 2>/dev/null || echo "~")
elif [ -f go.mod ]; then
  LANGUAGE="Go"
  RUNTIME_VERSION=$(go version 2>/dev/null | awk '{print $3}' || echo "~")
elif [ -f requirements.txt ] || [ -f pyproject.toml ] || [ -f setup.py ]; then
  LANGUAGE="Python"
  # Windows: try py first, then python3, then python
  if command -v py &>/dev/null; then
    RUNTIME_VERSION=$(py --version 2>/dev/null || echo "~")
    PY_CMD="py"
  elif command -v python3 &>/dev/null; then
    RUNTIME_VERSION=$(python3 --version 2>/dev/null || echo "~")
    PY_CMD="python3"
  else
    RUNTIME_VERSION=$(python --version 2>/dev/null || echo "~")
    PY_CMD="python"
  fi
  emit PY_CMD "$PY_CMD"
elif [ -f pom.xml ] || [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  LANGUAGE="Java/Kotlin"
  RUNTIME_VERSION=$(java --version 2>/dev/null | head -1 || echo "~")
fi

emit LANGUAGE "$LANGUAGE"
emit RUNTIME_VERSION "$RUNTIME_VERSION"

# ── Package manager ───────────────────────────────────────────────────────────

PKG_MANAGER="~"
[ -f pnpm-lock.yaml ]    && PKG_MANAGER="pnpm"
[ -f yarn.lock ]         && PKG_MANAGER="yarn"
[ -f bun.lockb ]         && PKG_MANAGER="bun"
[ -f package-lock.json ] && PKG_MANAGER="npm"
[ -f uv.lock ]           && PKG_MANAGER="uv"
[ -f Pipfile.lock ]      && PKG_MANAGER="pipenv"
[ -f requirements.txt ] && [ "$PKG_MANAGER" = "~" ] && PKG_MANAGER="pip"
emit PACKAGE_MANAGER "$PKG_MANAGER"

# ── Test framework & command ──────────────────────────────────────────────────

TEST_FRAMEWORK="~"
TEST_COMMAND="~"
TEST_PATHS="~"

if [ -f package.json ]; then
  DEPS=$(jq -r '(.devDependencies // {}) | keys | join(" ")' package.json 2>/dev/null || echo "")

  if echo "$DEPS" | grep -q '@playwright/test'; then
    TEST_FRAMEWORK="Playwright"
    TEST_COMMAND="npx playwright test"
    TEST_PATHS=$(ls -d tests/e2e e2e tests 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
  elif echo "$DEPS" | grep -q 'vitest'; then
    TEST_FRAMEWORK="Vitest"
    TEST_COMMAND="npx vitest run"
    TEST_PATHS=$(ls -d src 2>/dev/null || echo "src")
  elif echo "$DEPS" | grep -q '\bjest\b'; then
    TEST_FRAMEWORK="Jest"
    SCRIPT=$(jq -r '.scripts.test // empty' package.json 2>/dev/null || echo "")
    TEST_COMMAND="${SCRIPT:-npx jest}"
    TEST_PATHS=$(ls -d __tests__ tests src 2>/dev/null | head -1 || echo "~")
  else
    SCRIPT=$(jq -r '.scripts.test // empty' package.json 2>/dev/null || echo "")
    [ -n "$SCRIPT" ] && TEST_COMMAND="$SCRIPT"
  fi
fi

if [ "$TEST_FRAMEWORK" = "~" ] && [ -d addons/gut ]; then
  TEST_FRAMEWORK="GUT"
  TEST_COMMAND="godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit"
  TEST_PATHS="tests/"
fi

if [ "$TEST_FRAMEWORK" = "~" ] && { [ -f requirements.txt ] || [ -f pyproject.toml ]; }; then
  if grep -r 'import pytest' tests/ &>/dev/null 2>&1 || [ -f pytest.ini ] || \
     grep -q 'pytest' requirements.txt 2>/dev/null || \
     ([ -f pyproject.toml ] && grep -q 'pytest' pyproject.toml 2>/dev/null); then
    TEST_FRAMEWORK="pytest"
    VENV_PYTHON=".venv/Scripts/python.exe"
    [ ! -f "$VENV_PYTHON" ] && VENV_PYTHON=".venv/bin/python"
    if [ -f "$VENV_PYTHON" ]; then
      TEST_COMMAND="$VENV_PYTHON -m pytest tests/ -v"
    else
      TEST_COMMAND="${PY_CMD:-py} -m pytest tests/ -v"
    fi
    TEST_PATHS=$(ls -d tests/ test/ 2>/dev/null | tr '\n' ' ' | sed 's/ $//' || echo "tests/")
  fi
fi

emit TEST_FRAMEWORK "$TEST_FRAMEWORK"
emit TEST_COMMAND   "$TEST_COMMAND"
emit TEST_PATHS     "$TEST_PATHS"

# ── CI / CD ───────────────────────────────────────────────────────────────────

DEPLOY_PLATFORM="~"
PRODUCTION_URL="~"
PREVIEW_URL_PATTERN="~"
BRANCH_BASE="main"

# Deploy platform detection
[ -f vercel.json ]   && DEPLOY_PLATFORM="Vercel"
[ -f fly.toml ]      && DEPLOY_PLATFORM="Fly.io"
[ -f netlify.toml ]  && DEPLOY_PLATFORM="Netlify"
[ -f wrangler.toml ] && DEPLOY_PLATFORM="Cloudflare Workers"

if [ "$DEPLOY_PLATFORM" = "~" ] && [ -d .github/workflows ]; then
  if grep -rl 'github-pages\|pages:' .github/workflows/ &>/dev/null 2>&1; then
    DEPLOY_PLATFORM="GitHub Pages"
  fi
fi

# Production URL
if [ -f CNAME ]; then
  CNAME_VAL=$(cat CNAME | tr -d '[:space:]')
  [ -n "$CNAME_VAL" ] && PRODUCTION_URL="https://$CNAME_VAL"
fi

if [ "$PRODUCTION_URL" = "~" ] && [ -d .github/workflows ]; then
  # Look for page_url output or explicit URL in workflow files
  URL=$(grep -rh 'page_url\|html_url\|url:' .github/workflows/ 2>/dev/null | \
        grep -o 'https://[^"'\''[:space:]]*' | head -1 || echo "")
  [ -n "$URL" ] && PRODUCTION_URL="$URL"
fi

# Preview URL pattern
if [ -d .github/workflows ]; then
  PREVIEW=$(grep -rh 'pr-preview\|preview_url\|pr-{' .github/workflows/ 2>/dev/null | \
            grep -o 'https://[^"'\''[:space:]]*{[^}]*}[^"'\''[:space:]]*' | head -1 || echo "")
  [ -n "$PREVIEW" ] && PREVIEW_URL_PATTERN="$PREVIEW"
fi

# Base branch
if [ -d .github ]; then
  BB=$(grep -rh 'branches:\|branch:' .github/workflows/ 2>/dev/null | \
       grep -o 'main\|master\|develop' | head -1 || echo "main")
  [ -n "$BB" ] && BRANCH_BASE="$BB"
fi

emit DEPLOY_PLATFORM     "$DEPLOY_PLATFORM"
emit PRODUCTION_URL      "$PRODUCTION_URL"
emit PREVIEW_URL_PATTERN "$PREVIEW_URL_PATTERN"
emit BRANCH_BASE         "$BRANCH_BASE"

# ── CI workflows (compact: name|trigger|purpose) ──────────────────────────────

CI_WORKFLOWS="~"
if [ -d .github/workflows ]; then
  ENTRIES=""
  for f in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$f" ] || continue
    FILE=$(basename "$f")
    WF_NAME=$(grep -m1 '^name:' "$f" | sed 's/^name:[[:space:]]*//' | tr -d '"' || echo "$FILE")
    TRIGGER=$(grep -A2 '^on:' "$f" | grep -v '^on:' | grep -v '^--' | \
              sed 's/[[:space:]]//g;s/://g' | head -1 || echo "~")
    ENTRIES="${ENTRIES}${FILE}|${WF_NAME}|${TRIGGER}; "
  done
  [ -n "$ENTRIES" ] && CI_WORKFLOWS=$(echo "$ENTRIES" | sed 's/; $//')
fi
emit CI_WORKFLOWS "$CI_WORKFLOWS"

# ── Companion reads ───────────────────────────────────────────────────────────

COMPANIONS=""
for f in AI_BACKENDS.md ASSET_POLICY.md ADMIN.md ARCHITECTURE.md CONTRIBUTING.md; do
  [ -f "$f" ] && COMPANIONS="$COMPANIONS $f"
done
COMPANIONS=$(echo "$COMPANIONS" | sed 's/^ //')
emit COMPANION_READS "${COMPANIONS:-~}"

# ── Windows signals ───────────────────────────────────────────────────────────

WINDOWS_PROJECT="false"
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if grep -qiE 'schtasks|pystray|winotify|winreg|win32api|pywin32|keyring' \
       requirements.txt pyproject.toml 2>/dev/null; then
    WINDOWS_PROJECT="true"
  fi
fi
[ -f scheduler/task_scheduler.py ] && WINDOWS_PROJECT="true"
emit WINDOWS_PROJECT "$WINDOWS_PROJECT"

# ── ADMIN.md ──────────────────────────────────────────────────────────────────

HAS_ADMIN_MD="false"
[ -f ADMIN.md ] && HAS_ADMIN_MD="true"
emit HAS_ADMIN_MD "$HAS_ADMIN_MD"
