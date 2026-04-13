---
name: progress
description: "Start, update, correct, and conclude knowledge progressions — sequences of numbered documents that track how understanding of a topic evolves across sessions. Use when the user asks to track an investigation, log a finding, correct a previous conclusion, or review the state of a research topic."
user_invocable: true
---

# /progress — Knowledge Progression Tracking

Manage knowledge progressions: sequences of numbered documents (baseline, deepening, correction, pivot, synthesis) that capture how understanding of a topic evolves across sessions.

**CLI base path:** `${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin`

## Usage

`/progress <subcommand> [args]`

## Typical Workflow

1. `/progress start "Topic Name"` — begin tracking
2. `/progress add baseline "Initial Analysis"` — record first understanding
3. `/progress add deepening "Deeper Look"` — build on prior docs
4. `/progress correct 1 "Updated Finding"` — fix earlier conclusions
5. `/progress show "Topic"` — verify progression state
6. `/progress conclude "Topic"` — mark complete

## Subcommands

### start — Begin a new progression

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-progression-init --project PROJECT --topic "Topic Name"
```

Determine PROJECT from `basename` of CWD. Ask the user for the topic name if not provided. Use `--project _global` for progressions not tied to any project.

Example: `/progress start ECS Task Placement Strategy`

### add — Add a document to a progression

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-progression-add \
  --project PROJECT --topic "TOPIC" --number NN \
  --title "Document Title" --type TYPE [--file PATH] [--corrects NN]
```

**Document types:** `baseline` (initial understanding), `deepening` (builds on prior docs), `correction` (fixes a previous doc — use `--corrects NN`), `pivot` (fundamental direction change), `synthesis` (consolidation of findings).

**Determine the next number** with `pi-progression-status` and use the next sequential value.

**Pipe content via stdin** using `--file -` (do NOT write to /tmp):

```bash
cat <<'DOC' | pi-progression-add --project PROJECT --topic TOPIC --number NN --title "Title" --type TYPE --file -
# Document Title

Content goes here...
DOC
```

After adding, verify with `pi-progression-status --project PROJECT --topic "TOPIC"` to confirm the document was recorded.

Example: `/progress add correction "Actual Cost is $3.9K not $387K" --corrects 1`

### correct — Shortcut for adding a correction

Equivalent to `add --type correction --corrects NN`. Use when a new finding invalidates a previous document.

Example: `/progress correct 1 "CUR shows actual cost is much lower"`

### conclude — Mark a progression as complete

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-progression-conclude --project PROJECT --topic "TOPIC"
```

Concluded progressions are no longer injected into session context but remain searchable.

### show — Show details of a specific progression

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-progression-status --project PROJECT --topic "TOPIC"
```

Shows: status, document list with types, corrections, current position.

### list — List all progressions

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-progression-status --project PROJECT
```

Add `--all` to list progressions across all projects.

### search — Search progressions across all projects

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-progression-search QUERY [--project PROJECT] [--limit N]
```

Searches all progression documents via FTS5 full-text search. Without `--project`, searches globally. To reindex: `pi-progression-search --reindex`.

Example: `/progress search "cost optimization"`

## Guidelines

- **One progression per investigation arc.** A new topic gets its own progression.
- **Number documents sequentially** starting from 00. Use `pi-progression-status` to find the next number.
- **Always mark corrections explicitly** with `--type correction --corrects NN` so the progression tracks what was wrong and why.
- **Write content that captures reasoning**, not just conclusions. Future sessions need to understand *why* a conclusion was reached.
