---
name: recall
description: Search episodic memory - sessions, progressions, and documents across all projects
user_invocable: true
---

# /recall - Search Everything

Search your archived sessions, progression documents, and indexed files across all projects.

## Usage

The user invokes `/recall <search terms>` to find relevant past work.

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

Present the results in a clean format. For sessions, highlight:
- Which sessions matched and when they occurred
- Key decisions made in those sessions
- Dead ends to avoid repeating

For progressions, highlight:
- Which project and topic the progression belongs to
- The matched snippet showing relevant content
- Note that progressions may be from other projects

If the user wants more detail about a specific session, the raw JSONL archive can be found at `${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/archives/<project>/<session-id>.jsonl`.

To search only documents: `--docs-only`
To search only progressions, use `/progress search` instead.

## Examples

- `/recall API optimization` - Find sessions and progressions about API optimization
- `/recall cost savings` - Find cost-related work across all projects
- `/recall --project myapp containers` - Search within myapp sessions only
- `/recall --recent 10` - Show last 10 sessions
