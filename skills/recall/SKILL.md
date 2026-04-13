---
name: recall
description: "Search past Claude Code sessions, progression documents, and indexed files across all projects. Use when the user asks to find previous conversations, look up past work, recall earlier decisions, or search session history."
user_invocable: true
---

# /recall — Search Everything

Search archived sessions, progression documents, and indexed files across all projects using full-text search.

## Usage

`/recall <search terms>`

## Instructions

When the user invokes `/recall`, run **both** searches and present combined results:

### 1. Search sessions

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-query "$ARGUMENTS"
```

### 2. Search progressions (cross-project)

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-progression-search "$ARGUMENTS"
```

If no arguments are provided, show recent sessions:

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-query --recent 5
```

If either search returns no results, suggest broadening terms or using `--recent` to browse recent sessions.

**For sessions**, highlight: which sessions matched and when, key decisions made, dead ends to avoid repeating.

**For progressions**, highlight: project and topic, matched snippet, note when results come from other projects.

For raw session detail: `${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/archives/<project>/<session-id>.jsonl`

**Flags:** `--docs-only` to search only documents. Use `/progress search` to search only progressions.

## Examples

- `/recall API optimization` — find sessions and progressions about API optimization
- `/recall cost savings` — find cost-related work across all projects
- `/recall --project myapp containers` — search within myapp sessions only
- `/recall --recent 10` — show last 10 sessions
