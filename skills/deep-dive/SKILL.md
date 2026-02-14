---
name: deep-dive
description: Generate a comprehensive deep-dive analysis of the current project's codebase
user_invocable: true
---

# /deep-dive - Codebase Deep Dive

Generate a comprehensive understanding of the current project — what it IS, how it works, and what a developer needs to know.

## Usage

The user invokes `/deep-dive` to create or refresh a deep-dive document for the current project.

## Instructions

When the user invokes `/deep-dive`:

1. **Check for existing deep-dive.** Look for `~/.claude/knowledge/<project>/deep-dive.md`.
   - If it exists, ask: "A deep dive already exists (generated <date>). Refresh it, or regenerate from scratch?"
   - If it doesn't exist, proceed to step 2.

2. **Explore the codebase thoroughly.** Use Explore agents and direct reads to understand:
   - Package manifests (package.json, requirements.txt, Cargo.toml, go.mod, etc.)
   - Entry points (src/index.*, main.*, app.*, cmd/*)
   - Key source files — routes, handlers, models, services
   - Test structure and patterns
   - Configuration files (tsconfig, webpack, vite, docker, CI/CD)
   - README, CLAUDE.md, and other docs
   - Database schemas, migrations
   - Infrastructure / deployment configs

3. **Synthesize into a structured deep-dive document** covering:
   - **Overview**: What this project does, 2-3 sentences
   - **Tech Stack**: Languages, frameworks, libraries, runtime
   - **Architecture**: High-level component diagram, data flow
   - **Directory Structure**: Narrated guide to the layout
   - **Entry Points**: Where execution starts
   - **Key Patterns**: Design patterns, conventions, idioms
   - **Dependencies**: Critical external deps
   - **Deployment**: How it gets deployed
   - **Development Workflow**: Run locally, test, build
   - **Gotchas**: Non-obvious things, tech debt, quirks

4. **Write the document** to `~/.claude/knowledge/<project>/deep-dive.md` with YAML frontmatter:

```markdown
---
type: deep-dive
project: <project-name>
generated: <ISO-8601 timestamp>
model: interactive
project_path: <absolute path to project>
---

<deep-dive content>
```

5. **Commit and push** to the knowledge repo:
```bash
cd ~/.claude/knowledge && git add -A && git commit -m "Deep dive: <project>" && git push
```

6. **Confirm** to the user what was generated and where.

## Guidelines

- Be specific and concrete — reference actual file paths, function names, config values
- This is a reference document, not a tutorial. Be dense with information.
- Keep total length between 1500-4000 words
- If refreshing, add a "Changes Since Last Analysis" section at the top
- Use code blocks for file paths, commands, and code snippets
