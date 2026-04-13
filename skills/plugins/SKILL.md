---
name: plugins
description: "List all installed plugins, skills, CLI tools, and MCP servers available in the current environment. Use when the user asks what commands are available, what skills are installed, or says 'what can you do'."
user_invocable: true
---

# /plugins — Discover Installed Plugins & Skills

Scan the environment to discover all installed plugins, skills, and commands. Reads the filesystem and settings — not a hardcoded list.

## Instructions

Run the following discovery script, then present the results as grouped markdown tables.

```bash
echo "=== SCANNING PLUGINS & SKILLS ==="

# 1. PI skills (always present if PI is installed)
echo ""
echo "## PI_SKILLS"
PI_SKILLS_DIR="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/project-intelligence}/skills"
if [[ -d "$PI_SKILLS_DIR" ]]; then
    for skill_dir in "$PI_SKILLS_DIR"/*/; do
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        name=$(basename "$skill_dir")
        desc=$(grep '^description:' "$skill_dir/SKILL.md" 2>/dev/null | head -1 | sed 's/^description: *"*//;s/"*$//')
        echo "SKILL|/$name|$desc|pi"
    done
fi

# 2. User-level commands (~/.claude/commands/)
echo ""
echo "## USER_COMMANDS"
USER_CMD_DIR="$HOME/.claude/commands"
if [[ -d "$USER_CMD_DIR" ]]; then
    for ns_dir in "$USER_CMD_DIR"/*/; do
        [[ -d "$ns_dir" ]] || continue
        ns=$(basename "$ns_dir")
        for cmd_file in "$ns_dir"/*.md; do
            [[ -f "$cmd_file" ]] || continue
            cmd=$(basename "$cmd_file" .md)
            desc=$(head -5 "$cmd_file" | grep '^#' | grep -iv "usage\|example" | head -1 | sed 's/^# *//')
            echo "SKILL|/$ns $cmd|$desc|user ($ns)"
        done
    done
    for cmd_file in "$USER_CMD_DIR"/*.md; do
        [[ -f "$cmd_file" ]] || continue
        cmd=$(basename "$cmd_file" .md)
        desc=$(head -5 "$cmd_file" | grep '^#' | grep -iv "usage\|example" | head -1 | sed 's/^# *//')
        echo "SKILL|/$cmd|$desc|user"
    done
fi

# 3. Project-level commands (.claude/commands/ in CWD)
echo ""
echo "## PROJECT_COMMANDS"
PROJECT_CMD_DIR="${CWD:-.}/.claude/commands"
if [[ -d "$PROJECT_CMD_DIR" ]]; then
    for ns_dir in "$PROJECT_CMD_DIR"/*/; do
        [[ -d "$ns_dir" ]] || continue
        ns=$(basename "$ns_dir")
        for cmd_file in "$ns_dir"/*.md; do
            [[ -f "$cmd_file" ]] || continue
            cmd=$(basename "$cmd_file" .md)
            desc=$(head -5 "$cmd_file" | grep '^#' | grep -iv "usage\|example" | head -1 | sed 's/^# *//')
            echo "SKILL|/$ns $cmd|$desc|project"
        done
    done
    for cmd_file in "$PROJECT_CMD_DIR"/*.md; do
        [[ -f "$cmd_file" ]] || continue
        cmd=$(basename "$cmd_file" .md)
        desc=$(head -5 "$cmd_file" | grep '^#' | grep -iv "usage\|example" | head -1 | sed 's/^# *//')
        echo "SKILL|/$cmd|$desc|project"
    done
else
    echo "NONE"
fi

# 4. Registered plugins (from settings.json)
echo ""
echo "## REGISTERED_PLUGINS"
SETTINGS="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS" ]] && command -v python3 &>/dev/null; then
    cat "$SETTINGS" | python3 -c "
import json, sys
try:
    settings = json.load(sys.stdin)
    mcps = settings.get('mcpServers', {})
    for name, config in mcps.items():
        cmd = config.get('command', '')
        print(f'MCP|{name}|{cmd}|mcp-server')
except:
    pass
" 2>/dev/null
fi

# 5. CLI tools (pi-* commands)
echo ""
echo "## CLI_TOOLS"
PI_BIN="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/project-intelligence}/bin"
if [[ -d "$PI_BIN" ]]; then
    for cmd in "$PI_BIN"/pi-*; do
        [[ -x "$cmd" ]] || continue
        name=$(basename "$cmd")
        [[ -L "$cmd" ]] && continue
        desc=$(head -3 "$cmd" | grep '^#' | tail -1 | sed 's/^# *//')
        echo "CLI|$name|$desc|pi"
    done
fi

# 6. Beads (if initialized)
echo ""
echo "## BEADS"
if command -v bd &>/dev/null; then
    echo "CLI|bd|Git-backed issue tracker|beads"
else
    echo "NONE"
fi

echo ""
echo "=== SCAN COMPLETE ==="
```

## Formatting

Present results as grouped markdown tables. Group by source (PI, user, project, MCP, CLI, beads), skip empty groups, use descriptions found in files, and show a total count at the bottom. If a skill has sub-commands, show the namespace once and list sub-commands.

**Guidelines:**
- If `python3` is unavailable for MCP server detection, skip that section and note it in the output.
- If key directories (skills dir, bin dir) do not exist, skip those sections rather than showing errors.
