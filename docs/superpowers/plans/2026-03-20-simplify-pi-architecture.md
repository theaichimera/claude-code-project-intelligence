# Simplify PI Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove skills, deep-dives, checkpoints, and patterns from PI, leaving only progressions + recall + remember as the three core concepts.

**Architecture:** Archive removed library/bin/test/skill files to `archive/` directory. Clean up references in context injection, hooks, config, DB schema, install scripts, and docs.

**Tech Stack:** Bash, git

---

## File Map

### Archive (move to `archive/`)
- `lib/synthesize.sh`
- `lib/deep-dive.sh`
- `lib/patterns.sh`
- `bin/pi-synthesize`, `bin/episodic-synthesize`
- `bin/pi-deep-dive`, `bin/episodic-deep-dive`
- `bin/pi-patterns`, `bin/episodic-patterns`
- `bin/pi-checkpoint`
- `tests/test-synthesize.sh`
- `tests/test-deep-dive.sh`
- `tests/test-patterns.sh`
- `skills/save-skill/` (entire directory)

### Modify
- `lib/config.sh` — remove synthesize/deep-dive/patterns config vars
- `lib/db.sh` — remove synthesis_log, user_patterns, pattern_evidence, pattern_extraction_log table creation
- `bin/episodic-context` + `bin/pi-context` — remove skills injection, patterns injection, checkpoint injection
- `bin/pi-backfill` + `bin/episodic-backfill` — remove --synthesize and --patterns
- `hooks/on-session-start.sh` — remove pattern extraction block
- `tests/run-all.sh` — remove test-synthesize, test-deep-dive from core; test-patterns from regression
- `skills/progress/SKILL.md` — remove checkpoint references in behavioral instructions
- `skills/help/SKILL.md` — update to reflect simplified architecture
- `install.sh` — remove /save-skill skill installation
- `CLAUDE.md` — rewrite to reflect simplified architecture

### Keep unchanged
- `lib/progression.sh`, `lib/index.sh`, `lib/knowledge.sh`, `lib/db.sh` (core tables), `lib/extract.sh`, `lib/summarize.sh`
- `bin/pi-query`, `bin/pi-remember`, `bin/pi-progression-*`, `bin/pi-progression-search`
- `skills/recall/`, `skills/remember/`, `skills/progress/`, `skills/reflect/`, `skills/activity/`, `skills/plugins/`
- `hooks/on-stop.sh`

---

### Task 1: Archive removed files

**Files:**
- Create: `archive/` directory
- Move: 15 files/directories listed above

- [ ] **Step 1: Create archive directory and move files**

```bash
mkdir -p archive/lib archive/bin archive/tests archive/skills

# Library files
git mv lib/synthesize.sh archive/lib/
git mv lib/deep-dive.sh archive/lib/
git mv lib/patterns.sh archive/lib/

# Bin files
git mv bin/pi-synthesize archive/bin/ 2>/dev/null || true
git mv bin/episodic-synthesize archive/bin/ 2>/dev/null || true
git mv bin/pi-deep-dive archive/bin/ 2>/dev/null || true
git mv bin/episodic-deep-dive archive/bin/ 2>/dev/null || true
git mv bin/pi-patterns archive/bin/ 2>/dev/null || true
git mv bin/episodic-patterns archive/bin/ 2>/dev/null || true
git mv bin/pi-checkpoint archive/bin/ 2>/dev/null || true

# Test files
git mv tests/test-synthesize.sh archive/tests/
git mv tests/test-deep-dive.sh archive/tests/
git mv tests/test-patterns.sh archive/tests/

# Skill directories
git mv skills/save-skill archive/skills/
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "refactor: archive removed features (skills, deep-dive, checkpoint, patterns)"
```

---

### Task 2: Clean up context injection

This is the highest-impact change. Both `bin/episodic-context` and `bin/pi-context` need the same changes (they're copies of each other).

**Files:**
- Modify: `bin/episodic-context`
- Modify: `bin/pi-context`

- [ ] **Step 1: Remove behavioral instructions for checkpoints**

In `bin/episodic-context` (and `bin/pi-context`), remove the "Context Checkpointing" section from the PIINSTRUCTIONS heredoc (lines 110-127). Keep the progression instructions (lines 66-108).

- [ ] **Step 2: Remove pattern injection block**

Remove lines 157-164 (the `pi_patterns_generate_context` block):
```bash
# Output user behavioral patterns (cross-project, goes before project-specific context)
if type pi_patterns_generate_context &>/dev/null; then
    ...
fi
```

- [ ] **Step 3: Remove skills injection block**

Remove the entire skills injection section (lines 196-276) — the `episodic_knowledge_list_skills` block with skill decay logic.

- [ ] **Step 4: Remove checkpoint injection block**

Remove lines 280-301 — the "Recent Checkpoints" section.

- [ ] **Step 5: Remove source of patterns.sh**

Remove line 9: `[[ -f "$BIN_DIR/../lib/patterns.sh" ]] && source "$BIN_DIR/../lib/patterns.sh"`

- [ ] **Step 6: Sync pi-context with episodic-context**

After making all changes to `episodic-context`, copy it to `pi-context`:
```bash
cp bin/episodic-context bin/pi-context
```

- [ ] **Step 7: Run existing tests**

Run: `bash tests/test-roundtrip.sh`
Expected: PASS (roundtrip test calls episodic-context)

Run: `bash tests/test-progression-search.sh`
Expected: ALL PASS

- [ ] **Step 8: Commit**

```bash
git add bin/episodic-context bin/pi-context
git commit -m "refactor: remove skills, patterns, checkpoints from context injection"
```

---

### Task 3: Clean up config.sh and db.sh

**Files:**
- Modify: `lib/config.sh`
- Modify: `lib/db.sh`

- [ ] **Step 1: Remove synthesize/deep-dive/patterns config vars from config.sh**

Remove these variable blocks from `lib/config.sh`:
- `EPISODIC_SYNTHESIZE_*` variables (model, thinking budget, transcript count/chars, every-N check)
- `EPISODIC_DEEP_DIVE_*` variables (model, thinking budget, timeout)
- `PI_PATTERNS_*` variables (model, thinking budget, extract every, max inject, dormancy days)
- `EPISODIC_SKILL_FRESH_DAYS`, `EPISODIC_SKILL_AGING_DAYS` (skill decay thresholds)

Keep all other config vars (paths, context count, archive, summarize, index, etc.).

- [ ] **Step 2: Remove archived feature tables from db.sh**

In `lib/db.sh`, in `episodic_db_init()`, remove the CREATE TABLE statements for:
- `synthesis_log`
- `user_patterns`
- `pattern_evidence`
- `pattern_extraction_log`

Keep: `sessions`, `summaries`, `sessions_fts`, `documents`, `documents_fts`, `archive_log`, `activities`, `activity_sources`, `activities_fts`.

Note: Don't DROP existing tables — just stop creating them. Existing DBs will have them harmlessly.

- [ ] **Step 3: Run tests**

Run: `bash tests/test-init.sh`
Expected: PASS

Run: `bash tests/run-all.sh`
Expected: Core tests pass (test-synthesize, test-deep-dive removed so they won't run)

- [ ] **Step 4: Commit**

```bash
git add lib/config.sh lib/db.sh
git commit -m "refactor: remove synthesize/deep-dive/patterns config and DB tables"
```

---

### Task 4: Clean up hooks and backfill

**Files:**
- Modify: `hooks/on-session-start.sh`
- Modify: `bin/pi-backfill` and `bin/episodic-backfill`

- [ ] **Step 1: Remove pattern extraction from session start hook**

In `hooks/on-session-start.sh`, remove lines 47-51:
```bash
# Check if pattern extraction should run (background, non-blocking)
if patterns_bin=$(_pi_bin patterns 2>/dev/null); then
    source "$PI_ROOT/lib/patterns.sh" 2>/dev/null
    pi_patterns_maybe_extract &>/dev/null &
fi
```

Also update the context injection comment (line 53) to remove "skills" reference:
```bash
# Inject recent session context + active progressions for this project
```

- [ ] **Step 2: Clean up backfill scripts**

In `bin/pi-backfill` and `bin/episodic-backfill`, remove:
- `--synthesize` flag and its handling code
- `--patterns` flag and its handling code
- Source lines for `synthesize.sh` and `patterns.sh`

Keep: `--archive` and `--index` functionality.

- [ ] **Step 3: Commit**

```bash
git add hooks/on-session-start.sh bin/pi-backfill bin/episodic-backfill
git commit -m "refactor: remove pattern extraction from hooks and backfill"
```

---

### Task 5: Clean up test runner and install

**Files:**
- Modify: `tests/run-all.sh`
- Modify: `install.sh`

- [ ] **Step 1: Remove archived tests from run-all.sh**

In `tests/run-all.sh`:
- Remove `test-synthesize.sh` and `test-deep-dive.sh` from the core tests array
- Remove `test-patterns.sh` from the regression tests array

- [ ] **Step 2: Add test-progression-search.sh to run-all.sh**

Add `test-progression-search.sh` to the core tests array (it's a new test file from the cross-project feature that should be in the suite).

- [ ] **Step 3: Clean up install.sh**

Remove `/save-skill` skill installation lines. Keep `/recall`, `/progress`, `/remember`, `/reflect`, `/activity`, `/help`, `/plugins`.

- [ ] **Step 4: Run full test suite**

Run: `bash tests/run-all.sh`
Expected: All core and regression tests pass

- [ ] **Step 5: Commit**

```bash
git add tests/run-all.sh install.sh
git commit -m "refactor: update test suite and install script for simplified architecture"
```

---

### Task 6: Update skill files and help

**Files:**
- Modify: `skills/progress/SKILL.md`
- Modify: `skills/help/SKILL.md`

- [ ] **Step 1: Update /progress skill**

In `skills/progress/SKILL.md`, the skill is already mostly correct. Just ensure there are no references to checkpoints or skills in the guidelines section.

- [ ] **Step 2: Update /help skill**

In `skills/help/SKILL.md`, update to reflect the simplified architecture. Should list:
- `/progress` — Track evolving understanding (start, add, correct, conclude, show, list, search)
- `/recall` — Search past sessions and documents
- `/remember` — Store explicit preferences
- `/reflect` — Analyze a progression and synthesize current position
- `/activity` — View recent GitHub activity
- `/plugins` — Manage plugins

Remove references to `/save-skill`, `/deep-dive`, checkpoints, patterns, skill decay.

- [ ] **Step 3: Commit**

```bash
git add skills/progress/SKILL.md skills/help/SKILL.md
git commit -m "docs: update skill files for simplified architecture"
```

---

### Task 7: Rewrite CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Rewrite CLAUDE.md**

Remove entire sections for:
- `lib/synthesize.sh` description
- `lib/deep-dive.sh` description
- `lib/patterns.sh` description
- Skill Decay System section
- Deep Dive System section
- Preferences & Checkpoints section (keep preferences part, remove checkpoints)

Update:
- Architecture section to describe three concepts: progressions, recall, remember
- Three Storage Layers to remove skill/pattern references
- Core Data Flow to remove synthesis and pattern extraction steps
- Library Modules list to remove synthesize.sh, deep-dive.sh, patterns.sh
- Key Patterns section — keep SQL safety, FTS5, portability; remove skill-specific patterns

Add brief description of the cross-project progressions feature.

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: rewrite CLAUDE.md for simplified three-concept architecture"
```

---

### Task 8: Final validation and push

- [ ] **Step 1: Run full test suite**

Run: `bash tests/run-all.sh`
Expected: All tests pass

- [ ] **Step 2: Run progression search tests**

Run: `bash tests/test-progression-search.sh`
Expected: 14/14 PASS

- [ ] **Step 3: Verify context injection works**

Run: `bin/episodic-context --project pi-dev`
Expected: Output shows progressions, preferences, sessions — no skills, patterns, checkpoints

- [ ] **Step 4: Verify search works**

Run: `bin/pi-progression-search "cross-project"`
Expected: Finds the pi-dev progression

- [ ] **Step 5: Push to remote**

```bash
git push origin main
```
