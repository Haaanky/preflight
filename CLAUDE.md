# CLAUDE.md — Global Base

> This file applies to **every project** that uses this template.
> Project-specific overrides live in `.claude/CLAUDE.md` in the repo root.
> Read both files at the start of every session, every time — rules may change.

---

## AI Startup Protocol

Follow these steps **before** doing anything else in a session:

1. **Read this file** (`CLAUDE.md`) — global rules, always in effect
2. **Read `.claude/CLAUDE.md`** — check the PROJECT MANIFEST at the top
3. **Check `status:` in the manifest**
   - `pending` → run `/init-project` immediately; do not start the user's task until it completes
   - `complete` → use the manifest as ground truth; no init needed
4. **Read any files listed in `companion_reads`** in the manifest
   - For entries with `source: github`, fetch using `mcp__github__get_file_contents`:
     ```
     mcp__github__get_file_contents({ owner: "<owner>", repo: "<repo>", path: "<path>" })
     ```
   - Fetch **all** `source: github` entries — a project may pull from multiple repos
   - `type: task-queue` → implement every item with `status: pending` before proceeding
   - `type: reference` → read for context only; do not act on contents automatically
5. **Note `known_limitations`** — do not re-discover or re-diagnose these; treat them as facts

The `SessionStart` hook prints a summary automatically. Use it as a quick sanity check,
but always read the actual manifest — the hook output may be truncated.

---

## Scripts Before Reasoning

> **If a script can produce the answer, run the script. Don't read files manually to compute what a script already tells you.**

This is the core principle for token efficiency. Apply it everywhere:

| Instead of… | Do this |
|---|---|
| Reading `package.json`, `requirements.txt`, lockfiles to detect the stack | `bash .claude/scripts/detect.sh` |
| Manually editing the YAML manifest field by field | `bash .claude/scripts/fill-manifest.sh` |
| Writing stack-specific rules from memory | `bash .claude/scripts/gen-stack-rules.sh` |
| Doing all three | `bash .claude/scripts/init.sh` |

**When to use scripts vs reasoning:**
- **Scripts** — anything that can be answered by reading files and matching patterns: stack detection, version numbers, file existence, config values
- **Reasoning** — ambiguous trade-offs, unknown fields the script couldn't detect, architectural decisions, conflict resolution

**Adding new detection logic:**
If you discover a new pattern worth detecting (new framework, new platform, new Windows signal),
add it to `.claude/scripts/detect.sh` — not to a command file or CLAUDE.md.
Scripts are the single source of truth for detection; prose instructions are for the ambiguous remainder.

---

## MANDATORY RULES — Read First, Always

These rules apply to every task, every file, every session. No exceptions.

### 1. Read Before You Edit

- **Read every file before touching it** — no exceptions, even for one-line fixes
- Understand the surrounding code before suggesting any change
- Never assume a file's content from its name or a previous session

### 2. Scope Discipline

- **One logical change per task** — do not refactor unrelated code while implementing a feature
- **No speculative improvements** — only modify what was explicitly requested
- Do not add docstrings, comments, or type annotations to code you did not change
- Do not add error handling, fallbacks, or validation for scenarios that cannot happen
- Three similar lines of code is better than a premature abstraction
- If a user request conflicts with a rule in this file, flag it explicitly before proceeding

### 3. No Destructive Git Operations Without Confirmation

- Never `reset --hard`, `push --force`, or delete branches without explicit user approval
- Never skip hooks (`--no-verify`) unless the user explicitly requests it
- Never commit directly to `main` — see [Git Workflow](#git-workflow)
- Stage specific files by name — never `git add .` blindly

### 4. Confirm Before Irreversible Actions

Actions that affect shared state, external systems, or are hard to reverse require
explicit confirmation before proceeding — even if the user's request implies them:
pushing to remote, opening/closing PRs, deleting files or branches, running
database migrations, publishing to external services.

---

## Development Workflow

### Test-Driven Development (TDD)

**All new functionality and bug fixes MUST follow the Red → Green → Refactor cycle.**

1. **Red** — write a failing test that defines the expected behaviour; verify it fails
2. **Green** — write the minimum code to make the test pass; no more
3. **Refactor** — clean up while keeping all tests green

Rules:
- Do not write implementation code before a failing test exists
- Each TDD phase must produce a runnable project state; do not commit a broken build
- A skipped test (`test.skip`, `xit`, `pytest.mark.skip`, etc.) counts as a failing test
- Intermittent failures are bugs — fix the root cause, never increase timeouts as a workaround
- **No change is complete until all tests (new and existing) pass consistently in CI**

<!-- [MERGED: konflikt löst — källa: silver-octo-succotash]
silver-octo-succotash: "Iterera tills alla tester alltid är gröna"
didactic-winner: "0 failing tests before push"
Resolution: the stricter of the two — CI green required, not just local green -->

### CI-First Verification

- **Always verify in CI** — do not rely solely on local test runs
- Do not merge a PR until the full CI pipeline is green
- If a deploy workflow exists, verify the preview deployment functions correctly before merging
- After merging to `main`, confirm the production deploy workflow completes successfully

### Preview Deployments

When a PR preview workflow is configured:

1. Push to a feature branch and open a PR
2. Wait for the preview deploy to complete
3. Verify the preview URL loads correctly (not a blank page, correct assets)
4. Check E2E test results posted to the PR before merging

---

## Git Workflow

### Branch Naming

```
claude/<short-description>-<id>
```

Examples: `claude/fix-login-redirect-xK3`, `claude/add-export-button-9qF`

### Commit Messages

- Imperative present tense: `Add player jump`, not `Added` or `Adding`
- One logical change per commit
- Do not commit generated build artifacts, editor layout files, or secrets
- Include a link to the Red-phase commit in PR descriptions when using TDD

### Pull Requests

- All changes go through Pull Requests — never push directly to `main`
- PR description must state: what changed, why, and how it was tested
- Do not merge without CI green and (if applicable) preview verification

---

## Code Quality

- **Error handling at boundaries only** — validate external data (user input, API responses,
  file reads); do not add defensive guards inside well-understood internal logic
- **No magic numbers** — every non-trivial numeric literal must be a named constant
- **No hardcoded strings for behaviour** — use constants, config, or enums
- **No print/log statements in final code** — remove debug output before committing
- **No commented-out code** — delete unused code; git history preserves it
- **Functions do one thing** — clear, single responsibility; aim for under 30 lines
- **Avoid deep nesting** — maximum 3 levels of indentation per function; extract helpers

### The Boy Scout Rule

> "Always leave code better than you found it."

When you touch a file, leave it in a slightly better state than when you arrived —
fix an obvious naming inconsistency, remove a dead import, clarify a confusing
condition. The improvement must be:

- **Small and safe** — not a full refactor; one or two things max per visit
- **Within the file you were already editing** — do not reach into unrelated files
- **Non-breaking** — tests must still pass; no behavioural changes disguised as cleanup
- **Noted in the commit message** — e.g. `Fix login bug; remove unused import in auth.ts`

This rule does not override the scope discipline rule: do not use "leaving it better"
as justification for a large unsolicited refactor. Scout, don't redesign.

### Be Kind to Our Future Selves

> "If I came back to this in 6 months, what would I wish someone had written down?"

Before closing a task, ask this question about every non-obvious decision made.
Document the answer as close to the code as possible — inline comment, commit message,
or ADR (Architecture Decision Record) — not in a chat window that will be gone.

What is worth writing down:
- **Why** a surprising implementation was chosen over the obvious one
- **What was tried and rejected** — saves the next person from re-exploring dead ends
- **Constraints that shaped the design** — e.g. "can't use X because of the HTTPS proxy
  in CI", "Supabase anon key is intentionally public here"
- **Known footguns** — e.g. "must use `call_deferred()` here or it silently fails in exports"

What is *not* worth writing down:
- What the code already clearly says (`i++ // increment i`)
- Temporary decisions that will obviously be revisited
- Information already captured in git history or issue trackers

---

## Agent Architecture

This section defines how multi-agent tasks are structured in Claude Code.
All orchestrated work must follow these conventions.

### Orchestrator Responsibilities

The orchestrator agent (the top-level Claude Code session) is responsible for:

- **Planning** — decompose the task into atomic, independently executable subtasks
- **Delegation** — spawn subagents via the `Task` tool with a fully self-contained prompt;
  the subagent has no memory of the parent conversation
- **Conflict resolution** — if two subagents return contradictory results, the orchestrator
  decides the canonical answer using the more restrictive or more conservative option,
  documenting the resolution with `# [MERGED: ...]`
- **Final synthesis** — collect subagent reports and produce the unified output; never
  delegate the synthesis step itself

### Subagent Responsibilities

Each subagent spawned via `Task`:

- Operates within a **clearly bounded scope** — one file, one subsystem, one question
- Has **no side effects outside its assigned scope** — it must not push to remote,
  open PRs, send messages, or modify files outside its task boundary without the
  orchestrator explicitly granting that permission in the prompt
- Must **not re-spawn further subagents** unless the orchestrator's prompt explicitly
  allows it (avoid unbounded agent trees)
- Returns its result in the structured format below and does nothing else

### Subagent Report Format

Every subagent must end its response with a structured report block:

```json
{
  "status": "success | partial | failed",
  "output": "Brief summary of what was accomplished",
  "errors": ["List of errors or blockers encountered, empty array if none"],
  "artifacts": ["Optional: list of files changed, commands run, etc."]
}
```

The orchestrator must check `status` and `errors` before acting on `output`.
A `partial` or `failed` status must be escalated to the user — never silently dropped.

### When to Spawn a Subagent

Spawn a subagent when:
- A task is independently parallelisable (e.g., lint two separate modules)
- A task would pollute the main context with large tool outputs (e.g., full grep results)
- You need an independent second opinion without the current reasoning biasing the result

Do **not** spawn subagents for:
- Simple, directed searches (use Grep or Glob directly)
- Tasks that depend on the orchestrator's current working state
- Tasks where spawning overhead exceeds the benefit (one-liner lookups)

---

## Windows-Specific Rules

These rules apply whenever the project targets or runs on Windows.
`/init-project` activates them when it detects `requirements.txt` + Windows signals
(e.g. `schtasks`, `winreg`, `pystray`, `winotify`, `keyring` in dependencies).

### Elevation and Task Scheduler

- **Claude cannot elevate itself** — operations requiring admin rights (Task Scheduler
  install, writing to `HKLM` registry, installing services) must be handed to the user
  with an exact copy-paste command to run in an Administrator terminal
- Before asking for elevation, confirm it is genuinely required; prefer user-space
  alternatives (`HKCU` registry, user-level scheduled tasks) where possible
- Use `schtasks /Query /TN <TaskName> /FO LIST` to verify task state; never assume install succeeded
- **Reinstall to apply config changes** — if `task_scheduler.py` is modified, the task must
  be reinstalled (End → install → Run) for changes to take effect; a running task does not
  pick up XML changes automatically

### System Tray Icon and Interactive Session

- **`InteractiveToken` is required** for tray icons to appear in the user's desktop session.
  Without it, the task runs headless in session 0 and the icon is never shown.
  Task XML must include:
  ```xml
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  ```
- **RDP (Remote Desktop) edge case** — if the session is disconnected (not logged off),
  the task continues running in the background but the tray icon is invisible until the
  user reconnects. This is expected behaviour, not a bug. Document it in `ADMIN.md`.

### ADMIN.md Pattern

When a project has operations that require elevated rights or are risky to run incorrectly,
collect them in a dedicated `ADMIN.md` file at the repo root. This file is a companion read:

- List every command that needs an Administrator terminal
- Group by purpose: install, uninstall, reinstall, troubleshoot
- Include the `cd` to the correct directory before each command block
- Note which operations do *not* require elevation (e.g. `--set-password`, connection validation)

If `ADMIN.md` exists in the repo, add it to `companion_reads` in the manifest and read it
at session start. Never ask the user to find admin commands — point them to this file.

### Python on Windows

- **Use `py` not `python`** — the Python Launcher (`py.exe`) is the standard Windows
  entry point; verify availability with `where py` at session start
- **Virtualenv paths use backslash in cmd, forward slash in bash** — always use
  `.venv/Scripts/python.exe` for direct invocation to avoid activation ambiguity
- **Never commit `config.toml` or any file with user paths or credentials** — always
  provide a `config.toml.example` with placeholder values and verify `.gitignore` covers it

### Windows Credential Manager

- Passwords and secrets must be stored via `keyring` (Windows Credential Manager),
  never in config files, `.env`, or environment variables passed on the command line
- Inform the user where to find stored credentials:
  Kontrollpanelen → Autentiseringsuppgifter → Windows-autentiseringsuppgifter
- To update a stored password: `py main.py --set-password` (or equivalent entry point)

### Logging on Windows

- Log files land in `logs\` relative to the project root
- Read recent log output without requiring the user to open a file explorer:
  `powershell -Command "Get-Content logs\sync.log -Tail 30"`
- Never use `tail` — it is not available on Windows without WSL

---

## Security

- Never introduce command injection, XSS, SQL injection, or other OWASP Top 10 vulnerabilities
- Never commit secrets, API keys, or credentials — use environment variables or secret managers
- Validate all input at system boundaries (user input, external APIs, file reads)
- Do not upload potentially sensitive content to third-party tools without user confirmation
- If you notice you wrote insecure code, fix it immediately before continuing
