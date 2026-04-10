# /init-project — Auto-detect project context and fill the manifest

Run this command when the manifest `status` is `pending`.

**Run the script first. Do not read files manually to compute what the script already tells you.**

---

## What to do

### Step 1 — Run init.sh

```bash
bash .claude/scripts/init.sh
```

The script chains three sub-scripts automatically:
- `detect.sh` — inspects files, outputs `KEY=value` pairs
- `fill-manifest.sh` — writes values into the YAML manifest in `.claude/CLAUDE.md`
- `gen-stack-rules.sh` — generates stack-specific rules and inserts them

Read the script output. It ends with:
- A list of fields it could **not** auto-detect (marked as unknown)
- The current manifest `status`, `name`, `language`, `test_framework`, `deploy_platform`

### Step 2 — Handle unknowns

If the script reports unknown fields, ask the user **only for those** — one question,
listing all unknowns together. Do not ask about fields the script already filled.

Common genuinely-undetectable fields:
- `description` — if no `package.json` description and README is ambiguous
- `production_url` — if no CNAME and not referenced in workflow files
- `preview_url_pattern` — if no PR preview workflow exists

### Step 3 — Re-run with user-provided values (if needed)

If the user provides missing values, write them directly into `.claude/CLAUDE.md`
using the Edit tool. Then verify:

```bash
grep '^status:\|^name:\|^language:\|^test_framework:\|^deploy_platform:' .claude/CLAUDE.md
```

### Step 4 — Commit

```bash
git add .claude/CLAUDE.md
git commit -m "chore: initialize Claude Code project manifest"
```

If the repo has no commits yet, skip the commit.

### Step 5 — Report

```json
{
  "status": "success",
  "output": "Manifest complete. Detected: <language> / <test_framework> / <deploy_platform>",
  "errors": ["list any fields still unknown"],
  "artifacts": [".claude/CLAUDE.md"]
}
```

---

## Re-running after changes

To re-detect and overwrite all fields (e.g. after adding a new test framework):

```bash
FORCE=1 bash .claude/scripts/init.sh
```

---

## What the scripts detect

`detect.sh` outputs these fields as `KEY=value`:

| Field | Detection method |
|---|---|
| `NAME` | `package.json .name` → `project.godot config/name` → `basename $PWD` |
| `DESCRIPTION` | `package.json .description` → second line of README |
| `LANGUAGE` | Presence of `package.json` / `project.godot` / `Cargo.toml` / `go.mod` / `requirements.txt` |
| `RUNTIME_VERSION` | `node --version` / `py --version` / `godot --version` / etc. |
| `PY_CMD` | `py` (Windows launcher) → `python3` → `python` |
| `PACKAGE_MANAGER` | Lockfile presence: `pnpm-lock.yaml` → `yarn.lock` → `bun.lockb` → `package-lock.json` → `uv.lock` → `Pipfile.lock` |
| `TEST_FRAMEWORK` | `devDependencies` keys → `addons/gut/` → `pytest` in requirements |
| `TEST_COMMAND` | Framework-specific default, or `scripts.test` from `package.json` |
| `TEST_PATHS` | `ls tests/ __tests__/ e2e/ spec/` |
| `DEPLOY_PLATFORM` | `vercel.json` / `fly.toml` / `netlify.toml` / workflow `github-pages` references |
| `PRODUCTION_URL` | `CNAME` file → workflow URL output |
| `PREVIEW_URL_PATTERN` | Workflow files grep for `pr-preview` / `preview_url` |
| `BRANCH_BASE` | Workflow `branches:` keys |
| `CI_WORKFLOWS` | `.github/workflows/*.yml` names + triggers |
| `COMPANION_READS` | Presence of `AI_BACKENDS.md`, `ASSET_POLICY.md`, `ADMIN.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md` |
| `WINDOWS_PROJECT` | `requirements.txt` / `pyproject.toml` grep for `schtasks`, `pystray`, `keyring`, etc. |
| `HAS_ADMIN_MD` | Presence of `ADMIN.md` |

---

## Principle

> Scripts handle text processing. Claude handles ambiguity.

If a new detection pattern is needed, add it to `detect.sh` — not to this command file.
This keeps the logic machine-executable and token-efficient.
