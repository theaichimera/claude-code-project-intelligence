---
name: switch
description: Switch Claude Code to a different project folder with full context reload
user_invocable: true
---

# /switch - Switch Project Context

Switch to a different project folder. Claude exits and restarts in the target folder with that project's full context (progressions, sessions, preferences) loaded automatically.

## Usage

`/switch <project-name>`

## Instructions

When the user invokes `/switch`:

1. **Resolve the target project:**

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-switch "$ARGUMENTS"
```

This writes the target folder to `~/.claude/.switch-target`.

2. **Confirm the switch to the user:**

Tell them: "Switching to [project]. Exiting now — Claude will restart in the new folder."

3. **Exit the session.** The shell wrapper (`cc` function) will detect the switch target, `cd` to the folder, and relaunch Claude automatically.

**IMPORTANT:** After running `pi-switch`, you MUST exit. The switch only works if Claude exits so the shell wrapper can take over.

## Requirements

The user must use the `cc` shell wrapper function instead of calling `claude` directly. If not installed, tell them to add this to their `~/.zshrc`:

```bash
# Claude Code with project switching support
cc() {
  while true; do
    claude "$@"
    if [[ -f ~/.claude/.switch-target ]]; then
      local target
      target=$(cat ~/.claude/.switch-target)
      rm -f ~/.claude/.switch-target
      cd "$target" || break
      set --
    else
      break
    fi
  done
}
```

Then restart their shell: `source ~/.zshrc`

## Examples

- `/switch cloudfix` — Switch to the cloudfix project
- `/switch pi-dev` — Switch back to pi-dev
- `/switch ~/cc/new-project` — Switch to an absolute path
