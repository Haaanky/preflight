# /deploy-preview — Open a PR and verify the preview deployment

Automates the full branch → PR → preview → verify flow.
Enforces the rule: **never merge without a green preview**.

Seen in: **silver-octo-succotash** (GitHub Pages PR preview + E2E comment),
**didactic-winner** / **pages-cicd** (Godot WebAssembly preview via godot-preview.yml).

---

## What to do

1. **Confirm you are on a feature branch** (not `main`).
   ```bash
   git branch --show-current
   ```
   If on `main`, stop and ask the user which branch to use.

2. **Push the branch** to origin if not already pushed:
   ```bash
   git push -u origin HEAD
   ```

3. **Open a Pull Request** against `main` (or the configured base branch):
   ```bash
   gh pr create \
     --title "<IMPERATIVE_TITLE>" \
     --body "$(cat <<'EOF'
   ## Summary
   - <what changed>
   - <why>

   ## Test plan
   - [ ] CI green
   - [ ] Preview URL verified
   - [ ] E2E tests green

   🤖 Generated with Claude Code
   EOF
   )"
   ```

4. **Wait for the preview deploy workflow to complete**:
   ```bash
   gh run watch --repo <ORG>/<REPO>
   ```
   Or poll: `gh pr checks <PR_NUMBER>`

5. **Fetch and verify the preview URL** with WebFetch:
   ```
   WebFetch: <PREVIEW_URL_PATTERN_WITH_PR_NUMBER>
   Prompt: Does the page load with a title and asset tags?
           Are base paths correct? Is there a blank/error page?
   ```

6. **Check E2E results** — if the repo posts E2E results as a PR comment:
   ```bash
   gh api repos/<ORG>/<REPO>/issues/<PR_NUMBER>/comments \
     --jq '.[] | select(.body | contains("E2E")) | .body'
   ```
   Look for ✅. If ❌: read the failure, fix on the branch, push, iterate from step 4.

7. **Merge** only when preview and E2E are both green:
   ```bash
   gh pr merge <PR_NUMBER> --squash --auto
   ```

8. **Verify production deploy** after merge:
   ```bash
   gh run watch --repo <ORG>/<REPO>
   ```

---

## Placeholders to replace

| Placeholder | Example value |
|---|---|
| `<ORG>/<REPO>` | `Haaanky/silver-octo-succotash` |
| `<PREVIEW_URL_PATTERN_WITH_PR_NUMBER>` | `https://org.github.io/repo/pr-preview/pr-42/` |

---

## Known issues

- **Bot-authored PRs** (e.g. `copilot-swe-agent`) may require manual workflow approval
  from the repo owner due to GitHub's outside-collaborator policy. The owner must
  click "Approve and run" in the Actions tab before the preview workflow starts.
- **HTTPS proxy in Claude's cloud container**: Chromium cannot reach live deployed sites
  from inside a Claude Code cloud session. Always verify via CI, not `npx playwright test`
  run locally inside the container.
