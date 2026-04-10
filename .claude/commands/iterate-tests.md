# /iterate-tests — Schedule a recurring test-fix loop

Run the full test suite on a recurring schedule and automatically fix
failing tests until everything is green.

Seen in: **didactic-winner** (`/pw-loop`), **silver-octo-succotash** (manual CI iteration).
Generalised here to work with any test runner.

---

## What to do

1. Confirm the app / server is running (or set `APP_URL` to a deployed preview URL).

2. Call **CronCreate** with:
   ```
   cron:      */30 * * * *   (every 30 minutes — adjust to taste)
   recurring: true
   prompt: |
     Run <TEST_COMMAND> and report which tests are failing.
     For each failing test:
       1. Read the relevant source file(s) to understand the root cause.
       2. Fix the code (minimum change — do not refactor unrelated code).
       3. Re-run the full test suite and confirm the fix did not break other tests.
       4. Commit the fix to branch <BRANCH_NAME> with an imperative commit message.
     Stop iterating only when exit code is 0 (all tests pass).
     Report final status as { status, output, errors }.
   ```

3. Note the returned **job ID** so you can cancel it later with CronDelete.

---

## Placeholders to replace

| Placeholder | Example value |
|---|---|
| `<TEST_COMMAND>` | `npx playwright test` / `godot --headless -s addons/gut/gut_cmdln.gd` |
| `<BRANCH_NAME>` | `claude/complete-feature-abc123` |

---

## Fallback — GitHub Actions scheduled workflow

If **CronCreate** is not available (e.g. running outside the Agent SDK),
use a scheduled GitHub Actions workflow instead:

```yaml
# .github/workflows/iterate-tests.yml
name: Iterate Tests
on:
  schedule:
    - cron: "*/30 * * * *"
  workflow_dispatch:
jobs:
  iterate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: <TEST_COMMAND>
```

---

## Exit conditions

Stop the recurring job when:
- `status: "success"` and exit code is 0
- OR the user explicitly calls `CronDelete <job-id>`

Never let the loop run indefinitely without a stopping condition.
