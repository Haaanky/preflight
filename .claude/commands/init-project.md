# /init-project — Auto-detect project context and fill the manifest

Run this command at the start of a new project or whenever the manifest
`status` is `pending`. It detects the stack, CI setup, and constraints
automatically, then writes the result back to `.claude/CLAUDE.md`.

**Never ask the user for information that can be detected from files.**
Read first, ask only for what is genuinely ambiguous.

---

## Step 1 — Detect identity

```bash
# Project name
basename "$PWD"
cat package.json 2>/dev/null | jq -r '.name // empty'
grep -m1 'config/name' project.godot 2>/dev/null | sed 's/.*= "//' | tr -d '"'

# Description
cat package.json 2>/dev/null | jq -r '.description // empty'
head -3 README.md 2>/dev/null | tail -1
```

---

## Step 2 — Detect language and runtime

Check for these files in order:

| File present | Language | Runtime detection |
|---|---|---|
| `package.json` | TypeScript / JavaScript | `node --version` |
| `project.godot` | GDScript | `godot --version` |
| `Cargo.toml` | Rust | `rustc --version` |
| `go.mod` | Go | `go version` |
| `requirements.txt` / `pyproject.toml` | Python | `python --version` |
| `pom.xml` / `build.gradle` | Java / Kotlin | `java --version` |

```bash
ls package.json project.godot Cargo.toml go.mod requirements.txt pyproject.toml pom.xml build.gradle 2>/dev/null
```

---

## Step 3 — Detect package manager

```bash
ls package-lock.json yarn.lock pnpm-lock.yaml bun.lockb uv.lock Pipfile.lock 2>/dev/null
```

| Lockfile | Package manager |
|---|---|
| `package-lock.json` | npm |
| `yarn.lock` | yarn |
| `pnpm-lock.yaml` | pnpm |
| `bun.lockb` | bun |
| `uv.lock` | uv |
| `Pipfile.lock` | pipenv |

---

## Step 4 — Detect test framework and command

```bash
# Node projects: look at devDependencies
cat package.json 2>/dev/null | jq -r '(.devDependencies // {}) | keys[]'
cat package.json 2>/dev/null | jq -r '.scripts.test // empty'

# Check for config files
ls playwright.config.ts playwright.config.js jest.config.* vitest.config.* 2>/dev/null

# Godot: check for GUT addon
ls addons/gut/ 2>/dev/null

# Python: check for pytest
grep -r 'import pytest' tests/ 2>/dev/null | head -1
ls pytest.ini pyproject.toml setup.cfg 2>/dev/null
```

Derive `test_command`:
- `@playwright/test` in devDeps → `npx playwright test`
- `jest` → `npx jest`
- `vitest` → `npx vitest run`
- GUT addon present → `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
- `pytest` → `pytest`

```bash
# Test paths
ls -d tests/ __tests__/ spec/ e2e/ test/ src/**/*.test.* 2>/dev/null | head -10
```

---

## Step 5 — Detect CI workflows

```bash
ls .github/workflows/ 2>/dev/null
```

For each `.yml` file found, read it and extract:
- `name:` field
- `on:` trigger
- job names (keys under `jobs:`)
- any `environment:` references (reveals secrets setup)
- any URL patterns in deploy steps

```bash
cat .github/workflows/*.yml 2>/dev/null | grep -E 'name:|on:|environment:|url:|GAME_URL|PAGE_URL' | head -40
```

---

## Step 6 — Detect deploy platform and URLs

```bash
# GitHub Pages signals
ls CNAME 2>/dev/null && cat CNAME
grep -r 'github-pages\|pages:\|gh-pages' .github/workflows/ 2>/dev/null | head -5

# Other platforms
ls vercel.json fly.toml netlify.toml wrangler.toml Dockerfile 2>/dev/null

# Existing preview URL pattern in workflows
grep -r 'pr-preview\|preview_url\|PREVIEW_URL\|page_url' .github/workflows/ 2>/dev/null | head -5
```

---

## Step 7 — Detect companion reads

```bash
ls AI_BACKENDS.md ASSET_POLICY.md CONTRIBUTING.md ARCHITECTURE.md ADR/ docs/CLAUDE*.md 2>/dev/null
```

---

## Step 8 — Generate stack-specific rules

Based on the detected stack, write concise rules into the `## Stack-Specific Rules`
section of `.claude/CLAUDE.md`. Use only rules that are genuinely specific to
this stack — do not repeat global CLAUDE.md rules.

Examples by stack (include only what applies):

**Node + Playwright:**
```markdown
- Test files live in `<test_paths>`; add tests for every new route or component
- Playwright runs against `<preview_url_pattern>` in CI; do not run locally in cloud containers
- Environment variables must be defined in `.env.local` and declared in `vite-env.d.ts` (if Vite)
```

**Godot 4 + GDScript:**
```markdown
- Godot 4 latest stable only — never generate Godot 3 syntax
- Static typing required on all function signatures (`: Type` annotations)
- All scene changes via `get_tree().change_scene_to_file.call_deferred(path)` — never direct
- All audio routed through AudioManager autoload; never call `.play()` directly
- Signals for cross-scene communication; never `get_node()` across scene boundaries
```

**Python + pytest:**
```markdown
- Tests live in `<test_paths>`; run with `<test_command>`
- Use fixtures for shared setup; never duplicate setup code across test files
- Type annotations required on all public functions (PEP 484)
```

---

## Step 9 — Write the manifest

Edit `.claude/CLAUDE.md`:
1. Fill in every `~` field with the detected value (or `unknown` if genuinely undetectable)
2. Populate `ci_workflows` as a YAML list of objects
3. Add any discovered `known_limitations`
4. Add detected companion files to `companion_reads`
5. Write stack-specific rules into `## Stack-Specific Rules` (replace the placeholder comment)
6. **Set `status: complete`**

---

## Step 10 — Commit

```bash
git add .claude/CLAUDE.md
git commit -m "chore: initialize Claude Code project manifest"
```

If the repo has no commits yet, skip the commit and tell the user to commit after
their first real change.

---

## Step 11 — Report

Return a structured result:

```json
{
  "status": "success",
  "output": "Manifest complete. Detected: <language> / <test_framework> / <deploy_platform>",
  "errors": [],
  "artifacts": [".claude/CLAUDE.md"]
}
```

If any field could not be auto-detected, list it in `errors` with a short explanation
of what the AI needs the user to clarify.
