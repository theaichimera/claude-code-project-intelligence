---
name: remember
description: Store an explicit preference that persists across all sessions and projects
user_invocable: true
---

# /remember - Save a User Preference

Store an explicit preference that will be injected into every future session across all projects. Unlike behavioral patterns (which are learned automatically), preferences are things you explicitly tell Claude to remember.

## Usage

The user invokes `/remember <preference>` to store a preference.

## Instructions

When the user invokes `/remember`:

1. **Determine what to remember.** The user provides a preference after the command:
   - `/remember always use bun instead of npm` → store "always use bun instead of npm"
   - `/remember I prefer tables over bullet lists for comparisons` → store as-is
   - If the user just says `/remember` with no text, ask what they want you to remember

2. **Store the preference** by running:
```bash
pi-remember "the preference text here"
```

3. **Confirm** to the user what was saved.

4. **If the user wants to see or manage preferences:**
```bash
pi-remember --list      # Show all preferences
pi-remember --remove 3  # Remove preference #3
pi-remember --clear     # Remove all
```

## What Makes a Good Preference

- **Explicit directives**: "Always use TypeScript, never JavaScript"
- **Tool preferences**: "Use bun instead of npm"
- **Style preferences**: "Keep commit messages under 50 chars"
- **Workflow preferences**: "Always run tests before committing"
- **Communication preferences**: "Be concise, skip explanations unless asked"

## What Should NOT Be Preferences

- Project-specific knowledge → use `/save-skill` instead
- Things that should be learned from behavior → let patterns handle it
- Temporary or session-specific requests → just say it in the conversation

## Examples

- `/remember always use bun instead of npm`
- `/remember prefer functional style over classes in TypeScript`
- `/remember never auto-commit without asking first`
- `/remember use snake_case for Python, camelCase for TypeScript`
