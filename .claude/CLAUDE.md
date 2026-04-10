# .claude/CLAUDE.md — Per-Project Context

> **AI startup protocol:** Read the PROJECT MANIFEST below.
> If `status: pending` → run `/init-project` immediately before doing anything else.
> If `status: complete` → use the manifest as ground truth for this session.

---

## PROJECT MANIFEST

```yaml
# Filled automatically by /init-project on first session.
# Do NOT edit field names. Set values to ~ (null) to trigger re-detection.
status: pending   # pending | complete

# ── Identity ──────────────────────────────────────────────────────────────────
# detect: basename $PWD  OR  jq -r '.name' package.json  OR  grep 'config/name' project.godot
name: ~

# detect: jq -r '.description' package.json  OR  head -2 README.md | tail -1
description: ~

# detect: presence of package.json → Node/TypeScript, project.godot → GDScript/Godot,
#         requirements.txt → Python, Cargo.toml → Rust, go.mod → Go, pom.xml → Java
language: ~

# detect: node --version / python --version / godot --version / rustc --version
runtime_version: ~

# detect: package-lock.json → npm, yarn.lock → yarn, pnpm-lock.yaml → pnpm,
#         uv.lock → uv, Pipfile.lock → pipenv
package_manager: ~

# ── Testing ───────────────────────────────────────────────────────────────────
# detect: jq '.devDependencies | keys' package.json → look for playwright, jest, vitest, mocha;
#         ls addons/ in Godot → gut; grep -r 'import pytest' tests/
test_framework: ~

# detect: jq -r '.scripts.test' package.json  OR
#         check playwright.config.* → "npx playwright test"  OR
#         check gut_cmdln.gd → "godot --headless -s addons/gut/gut_cmdln.gd ..."
test_command: ~

# detect: ls -d tests/ __tests__/ spec/ e2e/ test/ 2>/dev/null | head -5
test_paths: ~

# ── CI / CD ───────────────────────────────────────────────────────────────────
# detect: ls .github/workflows/ → read each file, extract name + on: trigger + jobs keys
ci_workflows: []
  # - file: ~       # e.g. deploy.yml
  #   trigger: ~    # e.g. push to main
  #   purpose: ~    # e.g. build + deploy to GitHub Pages

# detect: presence of vercel.json → Vercel, fly.toml → Fly.io, netlify.toml → Netlify,
#         gh-pages branch or pages: in workflow → GitHub Pages, Dockerfile → container
deploy_platform: ~

# detect: read workflow file deploy step for URL output  OR  CNAME file  OR  README
production_url: ~

# detect: read pr-preview or preview workflow for URL construction pattern
preview_url_pattern: ~

# default unless a workflow or branch protection rule says otherwise
branch_base: main

# ── Constraints ───────────────────────────────────────────────────────────────
# Populated during init or as new limitations are discovered in later sessions.
# Format: "symptom — root cause — fix/workaround"
# Examples from real projects:
#   - "Task Scheduler install fails silently — requires admin terminal — user must run:
#      .venv\Scripts\python.exe -m scheduler.task_scheduler install (as Administrator)"
#   - "HTTPS proxy in CI blocks Chromium — do not run playwright locally inside Claude cloud"
#   - "call_deferred() required for scene changes — silent failure in Godot exported builds"
known_limitations: []
  # - ~

# Files that must be read at every session start (beyond CLAUDE.md itself).
# detect: look for AI_BACKENDS.md, ASSET_POLICY.md, CONTRIBUTING.md, ARCHITECTURE.md, ADMIN.md
# ADMIN.md — if present, always include: contains elevated commands for Task Scheduler etc.
companion_reads: []
  # - ~
```

---

## Stack-Specific Rules

> This section is written by `/init-project` after detecting the stack.
> If blank, run `/init-project` first.

<!-- STACK_RULES_PLACEHOLDER -->

---

## Session Notes

> Append discoveries here during a session so future sessions benefit.
> Format: `YYYY-MM-DD — <note>`. Keep entries short and factual.
> Remove entries older than ~30 days that are no longer relevant.

<!-- SESSION_NOTES_PLACEHOLDER -->
