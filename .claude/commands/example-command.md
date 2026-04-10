# /example-command — Template for a custom slash command

This file documents the anatomy of a Claude Code slash command.
Copy it, rename the file, and replace the content to create your own command.

---

## Purpose

One sentence: what problem does this command solve?

---

## When to use

- Trigger condition 1
- Trigger condition 2

---

## What to do

Step-by-step instructions Claude will follow when you invoke `/example-command`.

Commands can:
- Run bash commands via the Bash tool
- Read/edit files
- Call WebFetch to verify a URL
- Spawn subagents with Task (if `Task` is in `allowedTools`)
- Create cron jobs with CronCreate (requires Agent SDK)

### Step 1 — Describe the first action

```bash
# Shell command Claude should run
echo "hello"
```

### Step 2 — Describe the second action

<!-- Use WebFetch if the command needs to verify a URL -->
```
WebFetch: <URL>
Prompt: Does the page load correctly?
```

### Step 3 — Report result

Always end with a structured result so orchestrators can parse it:
```json
{
  "status": "success | partial | failed",
  "output": "What was accomplished",
  "errors": []
}
```

---

## Arguments

This command accepts optional arguments after the slash command name:
```
/example-command <ARG1> <ARG2>
```

| Argument | Required | Description |
|---|---|---|
| `<ARG1>` | No | Description of argument |

---

## Notes

- Any caveats, known limitations, or edge cases
