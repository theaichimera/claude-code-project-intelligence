---
name: help
description: "Quick reference card for all Project Intelligence commands"
user_invocable: true
---

# /help — Project Intelligence Quick Reference

Print the following reference card exactly as shown. Do not run any commands — just display this text.

---

## Progressions — How your understanding evolved

| Command | What it does |
|---------|-------------|
| `/progress start <topic>` | Start tracking a new investigation |
| `/progress add <type> "<title>"` | Add a document (baseline, deepening, correction, pivot, synthesis) |
| `/progress correct <N> "<title>"` | Correct a previous document |
| `/progress conclude <topic>` | Mark investigation complete |
| `/progress show <topic>` | See current state + open questions |
| `/progress list` | List all progressions |
| `/progress search <terms>` | Search across all progressions |

## Episodic Memory — What you discussed

| Command | What it does |
|---------|-------------|
| `/recall <terms>` | Search all your past Claude Code sessions and documents |

**Automatic:** Every session is archived, summarized, and indexed. Recent sessions are injected at start.

## Preferences

| Command | What it does |
|---------|-------------|
| `/remember <directive>` | Store a preference for all future sessions |

## Synthesis

| Command | What it does |
|---------|-------------|
| `/reflect [topic]` | Synthesize a progression's state via Opus |

## Activity Intelligence — What you did

| Command | What it does |
|---------|-------------|
| `/activity` | Show recent activity summary (GitHub + PI) |
| `/activity search <terms>` | Search your activities |
| `/activity gather` | Pull latest from GitHub |
| `/activity report` | Generate structured monthly report |
| `/activity <username>` | What has someone else been doing? (GitHub-only) |
| `/activity team` | Activity across all configured users |

**Setup:** `pi-activity sources add YOUR_GITHUB_USERNAME --org YOUR_ORG`

## Plugins

| Command | What it does |
|---------|-------------|
| `/plugins` | Manage installed plugins |

## CLI Commands (terminal)

```bash
# Episodic
pi-query <terms>              # Search sessions
pi-backfill                   # Import existing sessions (one-time)

# Activity
pi-activity sources add <user> --org <org>   # Add GitHub source
pi-activity gather                            # Pull activity
pi-activity search <terms>                    # Search activities
pi-activity report --user <slug> --month YYYY-MM  # Monthly report
pi-activity recent --days 7                   # Recent activity

# Progressions
pi-progression-status                         # All progressions
pi-progression-status --project <p> --topic <t>  # Specific one

# Preferences
pi-remember <text>            # Store preference
pi-remember --list            # List preferences

# Knowledge
pi-knowledge-sync             # Sync knowledge repo
pi-index --all                # Re-index documents

# Maintenance
pi-export ~/backup.tar.gz    # Export for another machine
pi-import ~/backup.tar.gz    # Import on new machine
```

## What runs automatically

- **Session start:** Archives previous session, syncs knowledge repo, injects context (progressions, preferences, recent sessions, activity, documents)
- **Session end:** Quick metadata archive, pushes knowledge repo

---

Full docs: [README.md](https://github.com/theaichimera/claude-code-project-intelligence)
