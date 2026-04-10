# Claude Code Project Template

A reusable, AI-native Claude Code configuration template.
Derived from six real projects (analysis date: 2026-04-10).

The core idea: **the AI fills in the project context itself at first startup**,
rather than requiring a human to manually edit placeholder values.

---

## How it works

```
First session                     Every subsequent session
─────────────────────────────     ──────────────────────────────────
SessionStart hook fires           SessionStart hook fires
  → session-start.sh runs           → session-start.sh reads manifest
  → manifest status = "pending"     → prints context summary to Claude
  → Claude sees the warning       Claude reads CLAUDE.md + .claude/CLAUDE.md
Claude reads CLAUDE.md            Claude proceeds with the user's task
Claude runs /init-project           (manifest already complete)
  → auto-detects stack
  → fills manifest fields
  → writes stack-specific rules
  → commits .claude/CLAUDE.md
Claude starts the user's task
```

---

## Directory Structure

```
template/
├── CLAUDE.md                        ← Global rules (all projects)
└── .claude/
    ├── CLAUDE.md                    ← PROJECT MANIFEST + per-project rules
    ├── settings.json                ← Tool permissions + hooks
    ├── hooks/
    │   ├── session-start.sh         ← Prints manifest summary at session open
    │   └── pre-commit.sh            ← Runs tests before every git commit
    └── commands/
        ├── init-project.md          ← /init-project: auto-detect and fill manifest
        ├── iterate-tests.md         ← /iterate-tests: recurring test-fix loop
        ├── deploy-preview.md        ← /deploy-preview: PR → preview → verify
        └── example-command.md       ← Template for new commands
```

---

## Quickstart

```bash
# 1. Copy the template into your repo
cp template/CLAUDE.md         your-repo/CLAUDE.md
cp -r template/.claude        your-repo/.claude
chmod +x your-repo/.claude/hooks/*.sh

# 2. Open Claude Code in the repo
# The SessionStart hook fires and detects status: pending

# 3. Claude runs /init-project automatically
# It detects your stack, fills the manifest, commits .claude/CLAUDE.md

# 4. Done — future sessions load the manifest from the hook summary
```

No manual editing of placeholder values required.

---

## File Reference

### `CLAUDE.md` — Global base

Rules common to all projects (appeared in ≥2 source repos):

| Section | What it covers |
|---|---|
| AI Startup Protocol | Step-by-step: check manifest → init if pending → read companion files |
| Mandatory Rules | Read-before-edit, scope discipline, no destructive git ops |
| TDD Red→Green→Refactor | Test-first, no skips, intermittent failures are bugs |
| CI-first verification | CI green required, not just local |
| Preview deployments | PR → preview → E2E → merge flow |
| Git workflow | Branch naming (`claude/<desc>-<id>`), commit style |
| The Boy Scout Rule | Leave every file slightly better than you found it |
| Be Kind to Our Future Selves | Document non-obvious decisions close to the code |
| Agent Architecture | Orchestrator vs subagent roles, `{ status, output, errors }` format |
| Security | OWASP Top 10, no committed secrets, validate at boundaries |

### `.claude/CLAUDE.md` — Project manifest + per-project rules

Two parts:

**PROJECT MANIFEST** — a YAML block with detection hints embedded as comments.
The AI reads the `status:` field at session start:
- `pending` → run `/init-project`
- `complete` → use values as-is

Fields detected automatically:
- `name`, `description` — from `package.json`, `project.godot`, or `README.md`
- `language`, `runtime_version` — from lockfiles and CLI version commands
- `package_manager` — from lockfile presence
- `test_framework`, `test_command`, `test_paths` — from devDeps and config files
- `ci_workflows` — from `.github/workflows/*.yml`
- `deploy_platform`, `production_url`, `preview_url_pattern` — from workflow files and `CNAME`
- `companion_reads` — from presence of `AI_BACKENDS.md`, `ARCHITECTURE.md`, etc.
- `known_limitations` — empty at init, filled as sessions progress

**Stack-Specific Rules** — written by `/init-project` after stack detection.
Empty placeholder until init runs. Examples of what ends up here:
- Node/Playwright: env var requirements, proxy limitations, test path conventions
- Godot 4: API restrictions, `call_deferred()` requirement, AudioManager pattern
- Python: typing requirements, fixture conventions

**Session Notes** — append-only log of discoveries made during sessions.
Format: `YYYY-MM-DD — <note>`. Prune after ~30 days.

### `.claude/settings.json`

```
allowedTools  → Read, Glob, Grep, Task (Task enables agent spawn)
denyTools     → empty by default
SessionStart  → runs session-start.sh
PreToolCall   → runs pre-commit.sh before any git commit
```

### `.claude/hooks/session-start.sh`

Runs automatically when Claude Code opens. Two behaviours:
- **Manifest pending** → prints a prominent warning; Claude must run `/init-project`
- **Manifest complete** → prints a one-screen summary (name, stack, test command, URLs, limitations)

The summary is informational — Claude must still read the actual manifest file.

### `.claude/hooks/pre-commit.sh`

Intercepts every `git commit` Claude attempts.
Reads `test_command` from the manifest and runs it.
Falls back to `npm test --if-present` if the manifest is not filled.
Exit non-zero aborts the commit.

### `.claude/commands/init-project.md` — `/init-project`

The key command. Runs a sequence of detection steps:

1. Identity (name, description)
2. Language and runtime
3. Package manager
4. Test framework and command
5. CI workflows
6. Deploy platform and URLs
7. Companion reads
8. Generate stack-specific rules
9. Write manifest with `status: complete`
10. Commit `.claude/CLAUDE.md`
11. Return structured `{ status, output, errors, artifacts }`

**Never asks the user for information that can be read from files.**
Lists undetectable fields in `errors` for the user to clarify.

### `.claude/commands/iterate-tests.md` — `/iterate-tests`

Schedules a `CronCreate` job that runs the test suite every 30 minutes,
fixes failures, commits, and repeats until exit code 0.
Reads `test_command` from the manifest — no hardcoded command.
Falls back to a GitHub Actions scheduled workflow if `CronCreate` is unavailable.

Source: generalised from `/pw-loop` in `didactic-winner`.

### `.claude/commands/deploy-preview.md` — `/deploy-preview`

Automates the full branch → PR → preview deploy → verify → merge flow.
Reads `preview_url_pattern` and `production_url` from the manifest.
Documents known limitations (bot PR approval gate, HTTPS proxy in cloud containers).

Source: generalised from `silver-octo-succotash` + `pages-cicd`.

### `.claude/commands/example-command.md` — `/example-command`

Documented anatomy of a slash command: arguments, step-by-step instructions,
structured result format. Copy to create new project-specific commands.

---

## Excluded from the global base (project-specific)

These patterns appeared in source repos but are too specific for the global base.
`/init-project` writes the relevant ones into `.claude/CLAUDE.md` after detection:

| Pattern | Source repo | Where it ends up |
|---|---|---|
| Supabase anon key embedding in PR preview | silver-octo-succotash | Stack-Specific Rules |
| Godot `call_deferred()` for scene changes | didactic-winner | Stack-Specific Rules + known_limitations |
| HTTPS proxy blocks Chromium in CI container | silver-octo-succotash | known_limitations |
| GUT 9.6.0 headless run command | didactic-winner | test_command field |
| Cloud-first AI backend selection | game-dev-tools / didactic-winner | Stack-Specific Rules (if AI APIs detected) |
| Bot PR approval gate (GitHub policy) | silver-octo-succotash | known_limitations |

---

## Merge conflict resolved

One rule conflict was found across source repos and resolved in the global base:

> **TDD completion criteria**
> - `silver-octo-succotash`: "iterate until always green in CI"
> - `didactic-winner`: "0 failures before push"
>
> Resolution: CI green required (stricter).
> Marked with `# [MERGED: konflikt löst — källa: silver-octo-succotash]` in `CLAUDE.md`.
