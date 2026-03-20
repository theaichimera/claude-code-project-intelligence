# Cross-Project Progression Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make progressions searchable across all projects via FTS5 indexing, support `_global` progressions, and add cross-project search.

**Architecture:** Extend existing per-project progression storage with `_global` path mapping in `lib/progression.sh`, add FTS5 indexing on document add via `lib/index.sh`, create new `bin/pi-progression-search` CLI, and update context injection in `bin/episodic-context` to include `_global` progressions.

**Tech Stack:** Bash, SQLite FTS5, existing PI library modules

**Spec:** `docs/superpowers/specs/2026-03-20-cross-project-progressions-design.md`

---

### Task 1: Add `_global` path mapping to `lib/progression.sh`

**Files:**
- Modify: `lib/progression.sh:35-49` (`_pi_progressions_dir` and `_pi_progression_dir`)
- Test: `tests/test-progression-search.sh` (new file)

- [ ] **Step 1: Write the failing tests for `_global` path mapping**

Create `tests/test-progression-search.sh`:

```bash
#!/usr/bin/env bash
# test-progression-search.sh: Test cross-project progression search
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_KNOWLEDGE="/tmp/episodic-test-prog-search-$$"

export EPISODIC_DB="/tmp/episodic-test-prog-search-$$.db"
export EPISODIC_LOG="/tmp/episodic-test-prog-search-$$.log"
export EPISODIC_KNOWLEDGE_DIR="$TEST_KNOWLEDGE"

source "$SCRIPT_DIR/../lib/progression.sh"
source "$SCRIPT_DIR/../lib/index.sh"

cleanup() {
    rm -f "$EPISODIC_DB" "$EPISODIC_LOG"
    rm -rf "$TEST_KNOWLEDGE"
}
trap cleanup EXIT

mkdir -p "$TEST_KNOWLEDGE"
episodic_db_init "$EPISODIC_DB"

echo "=== test-progression-search ==="

# Test 1: _global maps to _user/progressions/ on disk
echo -n "  1. _global maps to _user/progressions/... "
global_dir=$(_pi_progressions_dir "_global")
if [[ "$global_dir" == "$TEST_KNOWLEDGE/_user/progressions" ]]; then
    echo "PASS"
else
    echo "FAIL: expected $TEST_KNOWLEDGE/_user/progressions, got $global_dir"
    exit 1
fi

# Test 2: _global progression dir maps correctly
echo -n "  2. _global progression dir maps correctly... "
global_topic_dir=$(_pi_progression_dir "_global" "My Topic")
if [[ "$global_topic_dir" == "$TEST_KNOWLEDGE/_user/progressions/my-topic" ]]; then
    echo "PASS"
else
    echo "FAIL: expected $TEST_KNOWLEDGE/_user/progressions/my-topic, got $global_topic_dir"
    exit 1
fi

# Test 3: Regular project paths unchanged
echo -n "  3. Regular project paths unchanged... "
regular_dir=$(_pi_progressions_dir "cloudfix")
if [[ "$regular_dir" == "$TEST_KNOWLEDGE/cloudfix/progressions" ]]; then
    echo "PASS"
else
    echo "FAIL: expected $TEST_KNOWLEDGE/cloudfix/progressions, got $regular_dir"
    exit 1
fi

# Test 4: Other _-prefixed names treated as regular projects
echo -n "  4. _test treated as regular project... "
test_dir=$(_pi_progressions_dir "_test")
if [[ "$test_dir" == "$TEST_KNOWLEDGE/_test/progressions" ]]; then
    echo "PASS"
else
    echo "FAIL: expected $TEST_KNOWLEDGE/_test/progressions, got $test_dir"
    exit 1
fi

# Test 5: Create _global progression
echo -n "  5. Create _global progression... "
gdir=$(pi_progression_create "_global" "AWS Cost Patterns")
if [[ -d "$gdir" ]] && [[ -f "$gdir/progression.yaml" ]]; then
    if [[ "$gdir" == "$TEST_KNOWLEDGE/_user/progressions/aws-cost-patterns" ]]; then
        echo "PASS"
    else
        echo "FAIL: unexpected path $gdir"
        exit 1
    fi
else
    echo "FAIL: directory or yaml not created"
    exit 1
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-progression-search.sh`
Expected: FAIL at test 1 — `_global` currently maps to `$KNOWLEDGE/_global/progressions`

- [ ] **Step 3: Implement `_global` path mapping**

In `lib/progression.sh`, modify `_pi_progressions_dir()` (line 35-39):

```bash
_pi_progressions_dir() {
    local project
    project=$(pi_sanitize_name "$1")
    if [[ "$project" == "_global" ]]; then
        echo "$EPISODIC_KNOWLEDGE_DIR/_user/progressions"
    else
        echo "$EPISODIC_KNOWLEDGE_DIR/$project/progressions"
    fi
}
```

Modify `_pi_progression_dir()` (line 43-49):

```bash
_pi_progression_dir() {
    local project
    project=$(pi_sanitize_name "$1")
    local slug
    slug=$(_pi_topic_to_slug "$2")
    if [[ "$project" == "_global" ]]; then
        echo "$EPISODIC_KNOWLEDGE_DIR/_user/progressions/$slug"
    else
        echo "$EPISODIC_KNOWLEDGE_DIR/$project/progressions/$slug"
    fi
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-progression-search.sh`
Expected: Tests 1-5 PASS

- [ ] **Step 5: Run existing progression tests to verify no regressions**

Run: `bash tests/test-progressions.sh`
Expected: ALL PASS (18 tests)

- [ ] **Step 6: Commit**

```bash
git add lib/progression.sh tests/test-progression-search.sh
git commit -m "feat: add _global path mapping for cross-project progressions"
```

---

### Task 2: Add `file_type` override to `episodic_index_file()`

**Files:**
- Modify: `lib/index.sh:101-217` (`episodic_index_file`)
- Test: `tests/test-progression-search.sh` (append)

- [ ] **Step 1: Write the failing test for file_type override**

Append to `tests/test-progression-search.sh`:

```bash
# Test 6: Index progression document with file_type override
echo -n "  6. Index with file_type=progression... "
# Add a document to the _global progression
content_file=$(mktemp)
printf '# AWS Cost Patterns\n\nReserved instances save 40%% on steady-state.\n' > "$content_file"
doc_path=$(pi_progression_add "_global" "AWS Cost Patterns" 0 "Initial Findings" "baseline" "$content_file")
rm -f "$content_file"

# Index it with file_type override
episodic_index_file "$doc_path" "_global" "progression"

# Verify file_type in DB
ft=$(episodic_db_exec "SELECT file_type FROM documents WHERE project='_global' LIMIT 1;" "$EPISODIC_DB")
if [[ "$ft" == "progression" ]]; then
    echo "PASS"
else
    echo "FAIL: expected file_type=progression, got $ft"
    exit 1
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-progression-search.sh`
Expected: FAIL at test 6 — `episodic_index_file` doesn't accept third argument, `file_type` will be `md`

- [ ] **Step 3: Implement file_type override**

In `lib/index.sh`, modify `episodic_index_file()` at line 101-103:

```bash
episodic_index_file() {
    local file_path="$1"
    local project="$2"
    local file_type_override="${3:-}"
    local db="${EPISODIC_DB}"
```

At lines 153-155, replace the file_type derivation:

```bash
    # Determine file type from extension (or use override)
    local file_type
    if [[ -n "$file_type_override" ]]; then
        file_type="$file_type_override"
    else
        file_type="${file_name##*.}"
        file_type=$(echo "$file_type" | tr '[:upper:]' '[:lower:]')
    fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-progression-search.sh`
Expected: Tests 1-6 PASS

- [ ] **Step 5: Run existing tests to verify no regressions**

Run: `bash tests/test-index.sh`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add lib/index.sh tests/test-progression-search.sh
git commit -m "feat: add file_type override parameter to episodic_index_file"
```

---

### Task 3: Auto-index on progression document add

**Files:**
- Modify: `lib/progression.sh:169-259` (`pi_progression_add`)
- Test: `tests/test-progression-search.sh` (append)

- [ ] **Step 1: Write the failing test**

Append to `tests/test-progression-search.sh`:

```bash
# Test 7: Adding a progression doc auto-indexes it
echo -n "  7. Auto-index on progression add... "
# Create a project progression and add a doc
pi_progression_create "projA" "Migration Plan" >/dev/null
content_tmp=$(mktemp)
printf '# Migration Plan\n\nPhase 1: dual-write to both databases.\n' > "$content_tmp"
pi_progression_add "projA" "Migration Plan" 0 "Phase One" "baseline" "$content_tmp" >/dev/null
rm -f "$content_tmp"

# Check it was indexed
ft_a=$(episodic_db_exec "SELECT file_type FROM documents WHERE project='projA' AND file_type='progression' LIMIT 1;" "$EPISODIC_DB")
if [[ "$ft_a" == "progression" ]]; then
    echo "PASS"
else
    echo "FAIL: progression doc not auto-indexed (got: $ft_a)"
    exit 1
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-progression-search.sh`
Expected: FAIL at test 7 — `pi_progression_add` doesn't call indexing yet

- [ ] **Step 3: Add indexing call to `pi_progression_add()`**

In `lib/progression.sh`, add after the source line at the top (line 14):

```bash
# Source index.sh for FTS5 indexing of progression documents
_EPISODIC_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$_EPISODIC_LIB_DIR/index.sh" ]] && source "$_EPISODIC_LIB_DIR/index.sh"
```

Note: `_EPISODIC_LIB_DIR` is already defined at line 13 and `config.sh` is already sourced at line 14. We need to source `index.sh` after `config.sh`. Add after line 14:

```bash
[[ -f "$_EPISODIC_LIB_DIR/index.sh" ]] && source "$_EPISODIC_LIB_DIR/index.sh"
```

Then at the end of `pi_progression_add()`, before the `echo "$doc_path"` at line 258, add:

```bash
    # Index into FTS5 for cross-project search
    if type episodic_index_file &>/dev/null; then
        episodic_index_file "$doc_path" "$project" "progression" 2>/dev/null || true
    fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-progression-search.sh`
Expected: Tests 1-7 PASS

- [ ] **Step 5: Run existing progression tests**

Run: `bash tests/test-progressions.sh`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add lib/progression.sh tests/test-progression-search.sh
git commit -m "feat: auto-index progression documents into FTS5 on add"
```

---

### Task 4: Create `bin/pi-progression-search`

**Files:**
- Create: `bin/pi-progression-search`
- Test: `tests/test-progression-search.sh` (append)

- [ ] **Step 1: Write the failing tests for cross-project search**

Append to `tests/test-progression-search.sh`:

```bash
# Test 8: Cross-project search finds results from multiple projects
echo -n "  8. Cross-project search... "
# projA already has "Migration Plan" with "dual-write" content
# _global has "AWS Cost Patterns" with "Reserved instances" content
# Add another doc to projB
pi_progression_create "projB" "Cost Review" >/dev/null
content_tmp=$(mktemp)
printf '# Cost Review\n\nThe reserved instances cost analysis shows savings.\n' > "$content_tmp"
pi_progression_add "projB" "Cost Review" 0 "Analysis" "baseline" "$content_tmp" >/dev/null
rm -f "$content_tmp"

# Search for "reserved" — should find _global and projB
search_out=$("$SCRIPT_DIR/../bin/pi-progression-search" "reserved" 2>/dev/null)
if echo "$search_out" | grep -q "_global" && echo "$search_out" | grep -q "projB"; then
    echo "PASS"
else
    echo "FAIL: expected results from _global and projB"
    echo "  Output: $search_out"
    exit 1
fi

# Test 9: Search with --project filter
echo -n "  9. Search with --project filter... "
filtered=$("$SCRIPT_DIR/../bin/pi-progression-search" "reserved" --project projB 2>/dev/null)
if echo "$filtered" | grep -q "projB"; then
    if ! echo "$filtered" | grep -q "_global"; then
        echo "PASS"
    else
        echo "FAIL: _global should not appear in filtered results"
        exit 1
    fi
else
    echo "FAIL: projB not found in filtered results"
    echo "  Output: $filtered"
    exit 1
fi

# Test 10: Search with special characters (FTS5 escape safety)
echo -n "  10. FTS5 escape safety... "
special_out=$("$SCRIPT_DIR/../bin/pi-progression-search" 'cost OR DROP TABLE' 2>/dev/null || true)
# Should not error — FTS5 operators should be escaped
echo "PASS"

# Test 11: Search returns no results for non-matching query
echo -n "  11. No results for non-matching query... "
nomatch=$("$SCRIPT_DIR/../bin/pi-progression-search" "xyznonexistent" 2>/dev/null)
if [[ -z "$nomatch" || "$nomatch" == "No results found." ]]; then
    echo "PASS"
else
    echo "FAIL: expected no results"
    echo "  Output: $nomatch"
    exit 1
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-progression-search.sh`
Expected: FAIL at test 8 — `bin/pi-progression-search` doesn't exist

- [ ] **Step 3: Create `bin/pi-progression-search`**

```bash
#!/usr/bin/env bash
# pi-progression-search: Search progression documents across all projects via FTS5
set -euo pipefail

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BIN_DIR/../lib/db.sh"
source "$BIN_DIR/../lib/index.sh"

usage() {
    cat <<EOF
Usage: pi-progression-search QUERY [OPTIONS]

Search progression documents across all projects using full-text search.

Options:
  --project NAME    Filter to a specific project (or _global)
  --limit N         Max results (default: 10)
  --reindex         Reindex all existing progression documents before searching
  -h, --help        Show this help

Examples:
  pi-progression-search "cost optimization"
  pi-progression-search "migration" --project cloudfix
  pi-progression-search --reindex
EOF
}

QUERY=""
PROJECT_FILTER=""
LIMIT=10
REINDEX=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --project) PROJECT_FILTER="$2"; shift 2 ;;
        --limit) LIMIT="$2"; shift 2 ;;
        --reindex) REINDEX=1; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *)
            if [[ -z "$QUERY" ]]; then
                QUERY="$1"
            else
                QUERY="$QUERY $1"
            fi
            shift
            ;;
    esac
done

# Validate limit
[[ "$LIMIT" =~ ^[0-9]+$ ]] || LIMIT=10

# Handle reindex
if [[ $REINDEX -eq 1 ]]; then
    source "$BIN_DIR/../lib/progression.sh"
    echo "Reindexing all progression documents..."
    count=0
    # Walk all project dirs + _user/progressions
    for prog_base in "$EPISODIC_KNOWLEDGE_DIR"/*/progressions "$EPISODIC_KNOWLEDGE_DIR"/_user/progressions; do
        [[ -d "$prog_base" ]] || continue
        # Determine project name from path
        if [[ "$prog_base" == "$EPISODIC_KNOWLEDGE_DIR/_user/progressions" ]]; then
            proj="_global"
        else
            proj=$(basename "$(dirname "$prog_base")")
        fi
        for topic_dir in "$prog_base"/*/; do
            [[ -d "$topic_dir" ]] || continue
            for md_file in "$topic_dir"/*.md; do
                [[ -f "$md_file" ]] || continue
                if episodic_index_file "$md_file" "$proj" "progression" 2>/dev/null; then
                    count=$((count + 1))
                fi
            done
        done
    done
    echo "Reindexed $count progression documents."
    if [[ -z "$QUERY" ]]; then
        exit 0
    fi
fi

if [[ -z "$QUERY" ]]; then
    echo "ERROR: Search query required" >&2
    usage >&2
    exit 1
fi

# Build the search query
safe_query=$(episodic_sql_escape "$(episodic_fts5_escape "$QUERY")")

project_clause=""
if [[ -n "$PROJECT_FILTER" ]]; then
    safe_project=$(episodic_sql_escape "$PROJECT_FILTER")
    project_clause="AND d.project = '$safe_project'"
fi

results=$(episodic_db_exec "
SELECT d.project, d.title, d.file_name,
       snippet(documents_fts, 4, '>>>', '<<<', '...', 40) AS snippet
FROM documents_fts
JOIN documents d ON d.id = documents_fts.doc_id
WHERE documents_fts MATCH '$safe_query'
  AND d.file_type = 'progression'
  $project_clause
ORDER BY rank
LIMIT $LIMIT;" "$EPISODIC_DB" 2>/dev/null)

if [[ -z "$results" ]]; then
    echo "No results found."
    exit 0
fi

# Format output
while IFS='|' read -r proj title fname snippet; do
    [[ -z "$proj" ]] && continue
    printf '[%s] %s — %s\n' "$proj" "$title" "$fname"
    if [[ -n "$snippet" ]]; then
        printf '  %s\n' "$snippet"
    fi
    echo ""
done <<< "$results"
```

- [ ] **Step 4: Make it executable**

Run: `chmod +x bin/pi-progression-search`

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/test-progression-search.sh`
Expected: Tests 1-11 PASS

- [ ] **Step 6: Commit**

```bash
git add bin/pi-progression-search tests/test-progression-search.sh
git commit -m "feat: add pi-progression-search for cross-project FTS5 search"
```

---

### Task 5: Add `_global` progressions to context injection

**Files:**
- Modify: `bin/episodic-context:131-138`
- Test: `tests/test-progression-search.sh` (append)

- [ ] **Step 1: Write the failing test**

Append to `tests/test-progression-search.sh`:

```bash
# Test 12: Context injection includes _global progressions
echo -n "  12. Context injection includes _global... "
# _global "AWS Cost Patterns" is active
# Call context generation for a random project — _global should still appear
ctx_global=$(pi_progression_generate_context "_global" 2>/dev/null)
if echo "$ctx_global" | grep -q "AWS Cost Patterns"; then
    echo "PASS"
else
    echo "FAIL: _global progression not in context"
    echo "  Context: $ctx_global"
    exit 1
fi

# Test 13: episodic-context outputs both project and _global progressions
echo -n "  13. episodic-context dual injection... "
# We need to test that episodic-context calls generate_context for both
# Since episodic-context is a full script, test the output
ctx_full=$("$SCRIPT_DIR/../bin/episodic-context" --project projA 2>/dev/null || true)
# projA has "Migration Plan" active, _global has "AWS Cost Patterns" active
if echo "$ctx_full" | grep -q "Migration Plan"; then
    if echo "$ctx_full" | grep -q "AWS Cost Patterns"; then
        echo "PASS"
    else
        echo "FAIL: _global progression missing from episodic-context output"
        exit 1
    fi
else
    echo "FAIL: projA progression missing from episodic-context output"
    exit 1
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-progression-search.sh`
Expected: Test 12 PASS (generate_context already works with any project arg), Test 13 FAIL — episodic-context doesn't call for `_global`

- [ ] **Step 3: Update `bin/episodic-context` to inject `_global` progressions**

In `bin/episodic-context`, after the existing progression context block (lines 131-138), add:

```bash
# Output _global progressions (cross-project, always injected)
if type pi_progression_generate_context &>/dev/null; then
    global_prog_context=$(pi_progression_generate_context "_global" 2>/dev/null)
    if [[ -n "$global_prog_context" ]]; then
        # Replace "Active Progressions" heading with "Global Progressions"
        echo "${global_prog_context//## Active Progressions/## Global Progressions}"
        echo ""
    fi
fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-progression-search.sh`
Expected: Tests 1-13 PASS

- [ ] **Step 5: Commit**

```bash
git add bin/episodic-context tests/test-progression-search.sh
git commit -m "feat: inject _global progressions into all session contexts"
```

---

### Task 6: Add `--all` flag to `pi-progression-status`

**Files:**
- Modify: `bin/pi-progression-status:1-141`
- Test: `tests/test-progression-search.sh` (append)

- [ ] **Step 1: Write the failing test**

Append to `tests/test-progression-search.sh`:

```bash
# Test 14: --all flag lists progressions from all projects
echo -n "  14. --all lists cross-project progressions... "
all_out=$("$SCRIPT_DIR/../bin/pi-progression-status" --all 2>/dev/null)
# Should include projA, projB, and _global progressions
if echo "$all_out" | grep -q "projA" && echo "$all_out" | grep -q "projB" && echo "$all_out" | grep -q "_global"; then
    echo "PASS"
else
    echo "FAIL: --all should list progressions from all projects"
    echo "  Output: $all_out"
    exit 1
fi
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test-progression-search.sh`
Expected: FAIL — `--all` flag not recognized

- [ ] **Step 3: Implement `--all` flag**

In `bin/pi-progression-status`, add `ALL=0` variable and `--all) ALL=1; shift ;;` to the case statement. Then modify the listing section (line 125-140):

Replace the else block starting at line 125:

```bash
else
    if [[ $ALL -eq 1 ]]; then
        # List progressions across all projects
        echo "All Progressions:"
        echo ""
        printf '  %-20s %-30s %-12s %s\n' "PROJECT" "SLUG" "STATUS" "TOPIC"
        printf '  %-20s %-30s %-12s %s\n' "-------" "----" "------" "-----"
        for prog_base in "$EPISODIC_KNOWLEDGE_DIR"/*/progressions "$EPISODIC_KNOWLEDGE_DIR"/_user/progressions; do
            [[ -d "$prog_base" ]] || continue
            if [[ "$prog_base" == "$EPISODIC_KNOWLEDGE_DIR/_user/progressions" ]]; then
                proj="_global"
            else
                proj=$(basename "$(dirname "$prog_base")")
            fi
            listing=$(pi_progression_list "$proj" 2>/dev/null || true)
            while IFS=$'\t' read -r slug status topic; do
                [[ -z "$slug" ]] && continue
                printf '  %-20s %-30s %-12s %s\n' "$proj" "$slug" "$status" "$topic"
            done <<< "$listing"
        done
    else
        # List all progressions for the project
        listing=$(pi_progression_list "$PROJECT")
        if [[ -z "$listing" ]]; then
            echo "No progressions found for project: $PROJECT"
            exit 0
        fi

        echo "Progressions for $PROJECT:"
        echo ""
        printf '  %-30s %-12s %s\n' "SLUG" "STATUS" "TOPIC"
        printf '  %-30s %-12s %s\n' "----" "------" "-----"
        while IFS=$'\t' read -r slug status topic; do
            printf '  %-30s %-12s %s\n' "$slug" "$status" "$topic"
        done <<< "$listing"
    fi
fi
```

Also update the validation: when `--all` is set, `--project` is not required. Change the check at line 40-44:

```bash
if [[ -z "$PROJECT" && $ALL -eq 0 ]]; then
    echo "ERROR: --project is required (or use --all)" >&2
    usage >&2
    exit 1
fi
```

Update usage to mention `--all`:

```
  --all               List progressions across all projects
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/test-progression-search.sh`
Expected: Tests 1-14 PASS

- [ ] **Step 5: Commit**

```bash
git add bin/pi-progression-status tests/test-progression-search.sh
git commit -m "feat: add --all flag to pi-progression-status for cross-project listing"
```

---

### Task 7: Add reindex function to `lib/progression.sh`

**Files:**
- Modify: `lib/progression.sh`
- Test: `tests/test-progression-search.sh` (append)

- [ ] **Step 1: Write the failing test**

Append to `tests/test-progression-search.sh`:

```bash
# Test 15: Reindex existing progressions
echo -n "  15. Reindex existing progressions... "
# Clear the documents table to simulate pre-existing progressions
episodic_db_exec "DELETE FROM documents WHERE file_type='progression';" "$EPISODIC_DB"
# Verify they're gone
pre_count=$(episodic_db_exec "SELECT count(*) FROM documents WHERE file_type='progression';" "$EPISODIC_DB")
if [[ "$pre_count" != "0" ]]; then
    echo "FAIL: could not clear documents table"
    exit 1
fi
# Reindex
reindex_out=$("$SCRIPT_DIR/../bin/pi-progression-search" --reindex 2>/dev/null)
post_count=$(episodic_db_exec "SELECT count(*) FROM documents WHERE file_type='progression';" "$EPISODIC_DB")
if [[ "$post_count" -gt 0 ]]; then
    echo "PASS ($post_count docs reindexed)"
else
    echo "FAIL: no documents reindexed"
    exit 1
fi
```

- [ ] **Step 2: Run test to verify it passes**

Run: `bash tests/test-progression-search.sh`
Expected: Test 15 PASS — reindex logic is already in `pi-progression-search` from Task 4

Note: This test validates the reindex path built in Task 4. If it passes, no additional code is needed.

- [ ] **Step 3: Commit**

```bash
git add tests/test-progression-search.sh
git commit -m "test: add reindex validation test for progression search"
```

---

### Task 8: Update `/progress` skill with search and `--project` docs

**Files:**
- Modify: `skills/progress/SKILL.md`

- [ ] **Step 1: Update the skill file**

Add a new `search` subcommand section after the `list` section and update existing subcommands to mention `--project`:

In the `start` section, add after the command block:
```
To create a progression for a different project (cross-project), pass `--project`:
```bash
pi-progression-init --project cloudfix --topic "Topic Name"
```

Use `_global` for progressions not tied to any project:
```bash
pi-progression-init --project _global --topic "AWS Cost Patterns"
```
```

Add a new `search` section:

```markdown
### search - Search progressions across all projects

```bash
${CLAUDE_PLUGIN_ROOT:-~/.claude/project-intelligence}/bin/pi-progression-search QUERY [--project PROJECT] [--limit N]
```

Searches all progression documents via FTS5. Without `--project`, searches globally.

Example: `/progress search "cost optimization"`
Example: `/progress search "migration" --project cloudfix`
```

Add a `list --all` note to the existing list section.

- [ ] **Step 2: Commit**

```bash
git add skills/progress/SKILL.md
git commit -m "docs: update /progress skill with search and --project docs"
```

---

### Task 9: Finalize test file and run full suite

**Files:**
- Modify: `tests/test-progression-search.sh` (add footer)

- [ ] **Step 1: Add test footer**

Append to `tests/test-progression-search.sh`:

```bash
echo "=== test-progression-search: ALL PASS ==="
```

- [ ] **Step 2: Run full test suite**

Run: `bash tests/test-progression-search.sh`
Expected: ALL PASS

- [ ] **Step 3: Run all existing tests for regression check**

Run: `bash tests/run-all.sh`
Expected: ALL PASS across all 8 suites

- [ ] **Step 4: Commit final test file**

```bash
git add tests/test-progression-search.sh
git commit -m "test: finalize cross-project progression search test suite"
```

---

### Task 10: Create a progression in pi-dev to validate end-to-end

**Files:** None (runtime validation)

- [ ] **Step 1: Create a progression in pi-dev**

```bash
pi-progression-init --project pi-dev --topic "Cross-Project Progressions"
```

- [ ] **Step 2: Add a baseline document**

```bash
cat <<'DOC' | pi-progression-add --project pi-dev --topic "Cross-Project Progressions" --number 0 --title "Design and Implementation" --type baseline --file -
# Cross-Project Progressions: Design and Implementation

## Problem
Progressions were siloed per project — stored under per-project directories and only visible when working in that project's folder.

## Solution
- Added `_global` path mapping: `_global` project stores under `_user/progressions/`
- FTS5 indexing: progression documents auto-indexed on add with `file_type=progression`
- Cross-project search: `pi-progression-search` queries across all projects
- Context injection: `_global` progressions always injected alongside current project

## Key Design Decisions
- Kept per-project directory layout (backward compatible)
- `_global` is the only reserved project name (maps to `_user/progressions/`)
- No auto-injection of other projects' progressions (too noisy)
- Reindex via `--reindex` flag (not automatic on first search)
DOC
```

- [ ] **Step 3: Verify it appears in search**

```bash
pi-progression-search "cross-project"
```

Expected: Shows the pi-dev progression document

- [ ] **Step 4: Verify it appears in context injection**

```bash
episodic-context --project pi-dev | grep -A5 "Cross-Project"
```

Expected: Shows the progression in active progressions section
