# Cross-Project Progression Search & Global Progressions

**Date:** 2026-03-20
**Status:** Draft

## Problem

Progressions are siloed per project — stored under `~/.claude/knowledge/<project>/progressions/` and only visible when working in that project's folder. Users frequently work on cross-project topics from a single folder and need to:

1. Save a progression scoped to a different project without leaving their current directory
2. Save progressions that aren't project-specific at all
3. Search/discover progressions across all projects from any folder

## Solution: Approach 3

Keep the existing per-project directory layout. Add three capabilities:

1. **`--project` override** on all progression commands (defaults to CWD `basename` as today)
2. **FTS5 indexing** of progression documents into the existing `documents`/`documents_fts` tables
3. **Cross-project search** via new `pi-progression-search` command

## Design

### 1. `--project` Override

All progression CLI commands already accept `--project`. Today this is always derived from CWD. The change:

- When `--project` is explicitly passed, use that value instead of CWD derivation
- The value is a folder name (e.g., `cloudfix`, `pi-dev`) — the same `basename` that would be derived if you were in that folder
- Special reserved value `_global` stores under `~/.claude/knowledge/_user/progressions/` for project-agnostic topics

**Affected commands:**
- `bin/pi-progression-init` — already has `--project` flag, just needs `_global` path handling
- `bin/pi-progression-add` — same
- `bin/pi-progression-status` — `_global` path mapping, plus `--all` flag for cross-project listing
- `bin/pi-progression-conclude` — `_global` path mapping
- `skills/progress/SKILL.md` — update docs to show `--project` usage

**`_global` path mapping in library functions:**

`_pi_progressions_dir()` and `_pi_progression_dir()` in `lib/progression.sh` need explicit special-casing:

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

- Regular project: `~/.claude/knowledge/<project>/progressions/<topic>/`
- Global: `~/.claude/knowledge/_user/progressions/<topic>/`

The `progression.yaml` `project` field stores `_global` for global progressions.

**`doc_id` convention for global progressions:** Uses `_global:progressions/<topic>/<file>` as the project prefix (matching the logical project name), while `file_path` stores the actual `_user/progressions/...` filesystem path. `episodic_index_cleanup()` uses `file_path` for existence checks, so this is consistent.

### 2. FTS5 Indexing of Progression Documents

When `pi_progression_add()` creates a document, it also indexes it into SQLite.

**Index entry format:**
- `id`: `<project>:progressions/<topic_slug>/<filename>` (matches existing document ID convention)
- `project`: project name or `_global`
- `file_path`: absolute path to the markdown file
- `file_name`: e.g., `00_initial-analysis.md`
- `title`: document title from the `--title` argument
- `file_type`: `progression` (new value — distinguishes from regular indexed docs)
- `extracted_text`: full markdown content
- `content_hash`: SHA-256 of content (for change detection on reindex)

**Implementation:** Add an optional third parameter to `episodic_index_file()` in `lib/index.sh` for `file_type` override:

```bash
episodic_index_file() {
    local file_path="$1"
    local project="$2"
    local file_type_override="${3:-}"
    ...
    local file_type="${file_type_override:-${file_name##*.}}"
    file_type=$(echo "$file_type" | tr '[:upper:]' '[:lower:]')
```

Then call from `pi_progression_add()` in `lib/progression.sh`:

```bash
episodic_index_file "$doc_path" "$project" "progression"
```

This preserves backward compatibility — existing callers pass only two args and get auto-detection.

**Reindexing existing progressions:**
- New function `pi_progression_reindex(project)` that walks `progressions/` dirs and indexes each `.md` file
- `pi_progression_reindex_all()` walks all projects + `_user/progressions/`
- Triggered via `pi-progression-search --reindex` flag or automatically on first search if no progression docs found in FTS5

### 3. Cross-Project Search

**New command: `bin/pi-progression-search`**

```
pi-progression-search QUERY [--project PROJECT] [--limit N]
```

- Without `--project`: searches all progressions across all projects
- With `--project`: scopes to one project (or `_global`)
- Default limit: 10
- Output: project, topic slug, document title, relevance snippet, rank

**Implementation:** Query `documents_fts` WHERE `file_type = 'progression'` AND MATCH query. Use existing `episodic_fts5_escape()` for safe query handling.

**SQL pattern:**
```sql
SELECT d.project, d.file_name, d.title,
       snippet(documents_fts, 4, '>>>', '<<<', '...', 40) AS snippet,
       rank
FROM documents_fts
JOIN documents d ON d.id = documents_fts.doc_id
WHERE documents_fts MATCH '<escaped_query>'
  AND d.file_type = 'progression'
ORDER BY rank
LIMIT <limit>;
```

With `--project` adds: `AND d.project = '<project>'`

### 4. Context Injection Changes

**In `bin/episodic-context`:** Make two calls to `pi_progression_generate_context()`:

```bash
# Current project progressions (existing behavior)
pi_progression_generate_context "$PROJECT"

# Global progressions (new)
pi_progression_generate_context "_global"
```

The `_global` call output appears under a `## Global Progressions` heading. The heading distinction is handled by the caller in `episodic-context` (wrap the second call's output with the heading if non-empty).

`pi_progression_generate_context()` itself is unchanged — it already works with any project name. The `_global` path mapping in `_pi_progressions_dir()` ensures it reads from `_user/progressions/`.

**No auto-injection of other projects' progressions.** Cross-project discovery is via `/recall` or `/progress search`.

### 4a. Cross-Project Status Listing

`pi-progression-status --all` iterates all project directories:

```bash
for dir in "$EPISODIC_KNOWLEDGE_DIR"/*/progressions/ "$EPISODIC_KNOWLEDGE_DIR"/_user/progressions/; do
    # Extract project name from path
    # List progressions with project name prepended
done
```

Output format: `project | slug | status | topic` (adds project column to existing output).

### 5. `/progress` Skill Updates

Add new subcommand to `skills/progress/SKILL.md`:

- `search QUERY [--project PROJECT]` — cross-project FTS5 search
- Update `start` docs to show `--project` override usage
- Update `add` docs similarly

### 6. `/recall` Integration

Since progressions are indexed as `documents` with `file_type=progression`, they naturally appear in `/recall` document search results. The existing `format_doc_results()` in `bin/pi-query` already displays `file_type` — progressions will show type `progression` automatically. No changes needed to `pi-query` itself.

### 7. SQL Escaping

All user-provided values in SQL queries must use `episodic_sql_escape()`. The `--project` filter value must be escaped: `AND d.project = '$(episodic_sql_escape "$project")'`. FTS5 queries use the standard double-escape pattern: `episodic_sql_escape "$(episodic_fts5_escape "$query")"`.

### 8. Reindexing Behavior

`pi-progression-search --reindex` explicitly reindexes all progressions. First search does NOT auto-reindex (to avoid unexpected latency). Users who have existing progressions from before this feature should run `--reindex` once.

## Files Changed

| File | Change |
|------|--------|
| `lib/progression.sh` | Add `_global` path handling, call indexing after add, `pi_progression_reindex()` |
| `lib/index.sh` | Support `file_type` override in `episodic_index_file()` |
| `bin/pi-progression-init` | `_global` project path mapping |
| `bin/pi-progression-add` | `_global` path mapping, trigger FTS5 index |
| `bin/pi-progression-status` | `_global` path mapping, cross-project list mode |
| `bin/pi-progression-conclude` | `_global` path mapping |
| `bin/pi-progression-search` | **New file** — cross-project FTS5 search |
| `bin/episodic-context` | Inject `_global` progressions alongside current project |
| `skills/progress/SKILL.md` | Add `search` subcommand docs, `--project` examples |
| `tests/test-progression-search.sh` | **New file** — cross-project search tests |

## Test Plan

**`tests/test-progression-search.sh`:**
1. Create progression in project A, verify FTS5 index entry exists with `file_type=progression`
2. Create progression in project B, search without `--project`, verify both found
3. Search with `--project A`, verify only A's results returned
4. Create `_global` progression, verify it appears in cross-project searches
5. Verify `_global` maps to `_user/progressions/` on disk (NOT `_global/progressions/`)
6. Verify `_global` progressions appear in context injection alongside current project's progressions (both present simultaneously)
7. Reindex existing progressions via `--reindex`, verify they appear in search
8. Search with special characters and FTS5 operators (escape safety)
9. Verify `doc_id` format: `_global:progressions/<topic>/<file>` with `file_path` pointing to `_user/progressions/...`
10. Verify `--all` flag on `pi-progression-status` lists progressions from all projects + `_global`
11. Verify other `_`-prefixed project names (e.g., `_test`) are treated as regular projects, not mapped to `_user/`

## Non-Goals

- Auto-injecting cross-project progressions based on relevance matching
- Changing the on-disk directory layout for existing progressions
- Adding a GUI or interactive picker for cross-project progressions
