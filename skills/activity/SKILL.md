---
name: activity
description: "Summarize, search, and report on GitHub activity — commits, PRs, and issues — for a user or team. Use when the user asks about recent contributions, wants a monthly activity report, or needs to look up what someone worked on."
user_invocable: true
---

# /activity — Activity Intelligence

Summarize, search, and report on GitHub activity (commits, PRs, issues) for a user or team.

**CLI base path:** `${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity`

## Usage

`/activity [subcommand] [args]`

## Subcommands

### (no args) — Recent activity summary

Show a summary of recent activity for the current user.

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity recent
```

If the output is empty or says "No recent activities found", suggest running `/activity gather` first or configuring a source with `pi-activity sources add <github_username>`.

Present results grouped by day, showing activity type, repo, and title. Summarize at the top with counts (e.g., "3 issues, 2 PRs, 5 commits in the last 7 days").

### search — Search activities

Search across all tracked activities using full-text search.

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity search "$QUERY" --limit 20
```

Display results as a markdown table showing: activity type, date, repository, title/description, and URL (if available).

Example: `/activity search cost optimization`

### gather — Gather from all sources

Pull activity data from all configured GitHub sources.

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity gather
```

For a specific user or time range:

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity gather --user USERNAME --since YYYY-MM-DD
```

After gathering, report what was found: count, sources, and time range covered. If the command fails (e.g., GitHub API rate limit or authentication error), show the error and suggest checking credentials with `gh auth status`.

### report — Generate structured report

Generate a monthly activity report.

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity report --user USER_SLUG --month YYYY-MM --format summary
```

Defaults: `--month` = current month, `--user` = detected from git config. For JSON output, use `--format json`.

Format the report as markdown with sections for: summary counts by activity type, breakdown by repository, and notable items (high-impact PRs, large commits).

Example: `/activity report --month 2026-02`

### team — Show team activity

Show recent activity for all configured users.

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity sources list
```

Then for each source found, run:

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity recent --user USER_SLUG --days 7
```

If `sources list` returns no results, guide the user to add sources first. Present a combined view grouped by user, then by day.

Example: `/activity team`

### <username> — Show activity for a specific user

When the argument does not match any known subcommand, treat it as a GitHub username or user slug.

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity recent --user USERNAME --days 7
```

If no results, check for a configured source:

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-activity sources list --user USERNAME
```

If no source exists, suggest: `pi-activity sources add <github_username> --slug USERNAME --org <org>`

Example: `/activity dschwartzi`

## Guidelines

- Always run commands via Bash using the full CLI base path shown above.
- Format output as markdown tables or structured lists, not raw JSON.
- Use human-friendly dates (e.g., "Feb 15" not "2026-02-15T10:00:00Z").
- Group activities by day or by repo depending on what is most scannable.
- If the database is empty or a command returns no results, guide the user on how to set up sources and gather data.
