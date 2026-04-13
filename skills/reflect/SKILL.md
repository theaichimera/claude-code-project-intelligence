---
name: reflect
description: "Synthesize a knowledge progression by analyzing all its documents and updating the progression metadata with current position, corrections, and open questions. Use when the user asks to review a progression's state, synthesize findings, or update a topic summary after adding new documents."
user_invocable: true
---

# /reflect — Reflect on a Progression

Analyze all documents in a knowledge progression and update `progression.yaml` with a synthesized current position, corrections list, and open questions.

## Usage

`/reflect [TOPIC]`

If TOPIC is omitted, reflect on all active progressions for the current project.

## Instructions

1. **Identify the project** from `basename` of CWD.

2. **Find the progression:**
   ```bash
   ${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-progression-status --project PROJECT [--topic "TOPIC"]
   ```

3. **Read all documents in order.** The progression directory is at:
   ```
   ~/.claude/knowledge/PROJECT/progressions/TOPIC_SLUG/
   ```
   Read `progression.yaml` for the document list, then read each `.md` file sequentially.

4. **Call the Anthropic API** to analyze the full progression:

   ```
   System: You are analyzing a knowledge progression — a sequence of documents that tracks
   evolving understanding of a topic. Some documents may correct earlier ones. Synthesize
   the CURRENT state of understanding.

   User: Here is a knowledge progression on the topic: "{topic}"

   [Document 00: title (type)]
   {content}
   ...

   Produce:
   1. CURRENT_POSITION: 2-3 sentence summary of current best understanding.
   2. CORRECTIONS: Bullet list — "Doc NN claimed X, but Doc MM showed Y".
   3. OPEN_QUESTIONS: Bullet list of unresolved, actionable questions.
   ```

   Use `$EPISODIC_OPUS_MODEL` (default `claude-opus-4-6`) with extended thinking enabled. Budget: `$EPISODIC_SYNTHESIZE_THINKING_BUDGET` tokens.

   If the API call fails, report the error to the user and do not modify `progression.yaml`.

5. **Update progression.yaml** — set `current_position`, `corrections`, `open_questions`, and `updated` timestamp. Validate the YAML is parseable before proceeding.

6. **Commit and push** to the knowledge repo:
   ```bash
   cd ~/.claude/knowledge && git add -A && git commit -m "Reflect: PROJECT/TOPIC" && git push
   ```

7. **Report results** — current position summary, number of corrections, open questions listed.

## Example

```
User: /reflect ECS Task Placement

Reflecting on progression: ECS Task Placement Strategy (5 documents)...

Current Position:
  ECS tasks use spread placement with AZ constraints, costing $12K/yr
  in cross-AZ traffic. Binpack strategy would save ~$8K/yr.

Corrections:
  - Doc 01 claimed $387K DynamoDB cost, but Doc 03 showed actual cost is $3.9K/yr

Open Questions:
  - Would binpack affect availability during AZ failures?
  - What's the latency impact of same-AZ placement?

Updated: ~/.claude/knowledge/myapp/progressions/ecs-task-placement/progression.yaml
```

## Guidelines

- **Read ALL documents** in order — corrections only make sense in context.
- **Be specific** in the current position. Reference actual numbers, resources, and findings.
- **Corrections should trace the chain.** "Doc 01 said X, Doc 03 corrected to Y" — not just "Y is correct."
- **Open questions should be actionable.** "What is the cost?" not "More investigation needed."
- Sends full document text to the Anthropic API. Avoid including credentials or sensitive PII in progression documents.
