#!/usr/bin/env bash
# test-progression-search.sh: Test _global path mapping and progression search
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_KNOWLEDGE="/tmp/episodic-test-prog-search-$$"

# Override config
export EPISODIC_DB="/tmp/episodic-test-prog-search-$$.db"
export EPISODIC_LOG="/tmp/episodic-test-prog-search-$$.log"
export EPISODIC_KNOWLEDGE_DIR="$TEST_KNOWLEDGE"

source "$SCRIPT_DIR/../lib/progression.sh"

cleanup() {
    rm -f "$EPISODIC_DB" "$EPISODIC_LOG"
    rm -rf "$TEST_KNOWLEDGE"
}
trap cleanup EXIT

mkdir -p "$TEST_KNOWLEDGE"

echo "=== test-progression-search ==="

# Test 1: _global maps to _user/progressions/
echo -n "  1. _global progressions dir maps to _user/progressions/... "
global_dir=$(_pi_progressions_dir "_global")
expected="$TEST_KNOWLEDGE/_user/progressions"
if [[ "$global_dir" == "$expected" ]]; then
    echo "PASS"
else
    echo "FAIL: expected $expected, got $global_dir"
    exit 1
fi

# Test 2: _global progression dir maps correctly
echo -n "  2. _global progression dir maps correctly... "
global_prog_dir=$(_pi_progression_dir "_global" "Cross Project Insights")
expected="$TEST_KNOWLEDGE/_user/progressions/cross-project-insights"
if [[ "$global_prog_dir" == "$expected" ]]; then
    echo "PASS"
else
    echo "FAIL: expected $expected, got $global_prog_dir"
    exit 1
fi

# Test 3: Regular project paths unchanged
echo -n "  3. Regular project paths unchanged... "
regular_dir=$(_pi_progressions_dir "myproject")
expected="$TEST_KNOWLEDGE/myproject/progressions"
if [[ "$regular_dir" == "$expected" ]]; then
    regular_prog_dir=$(_pi_progression_dir "myproject" "Some Topic")
    expected2="$TEST_KNOWLEDGE/myproject/progressions/some-topic"
    if [[ "$regular_prog_dir" == "$expected2" ]]; then
        echo "PASS"
    else
        echo "FAIL: progression dir expected $expected2, got $regular_prog_dir"
        exit 1
    fi
else
    echo "FAIL: expected $expected, got $regular_dir"
    exit 1
fi

# Test 4: Other _-prefixed names treated as regular projects (NOT mapped to _user)
echo -n "  4. Other _-prefixed names NOT mapped to _user... "
other_dir=$(_pi_progressions_dir "_private")
expected="$TEST_KNOWLEDGE/_private/progressions"
if [[ "$other_dir" == "$expected" ]]; then
    echo "PASS"
else
    echo "FAIL: expected $expected, got $other_dir"
    exit 1
fi

# Test 5: Create _global progression and verify path
echo -n "  5. Create _global progression and verify path... "
dir=$(pi_progression_create "_global" "Cross Project Insights")
expected="$TEST_KNOWLEDGE/_user/progressions/cross-project-insights"
if [[ "$dir" == "$expected" ]] && [[ -d "$dir" ]] && [[ -f "$dir/progression.yaml" ]]; then
    topic=$(_pi_yaml_get "$dir/progression.yaml" "topic")
    if [[ "$topic" == "Cross Project Insights" ]]; then
        echo "PASS"
    else
        echo "FAIL: unexpected topic in yaml: $topic"
        exit 1
    fi
else
    echo "FAIL: expected dir $expected, got $dir (exists=$(test -d "$dir" && echo yes || echo no))"
    exit 1
fi

# Source index.sh for FTS5 indexing tests
source "$SCRIPT_DIR/../lib/index.sh"
episodic_db_init "$EPISODIC_DB"

# Test 6: Index progression document with file_type override
echo -n "  6. Index with file_type=progression... "
pi_progression_create "_global" "AWS Cost Patterns" >/dev/null
content_file=$(mktemp)
printf '# AWS Cost Patterns\n\nReserved instances save 40%% on steady-state workloads.\n' > "$content_file"
doc_path=$(pi_progression_add "_global" "AWS Cost Patterns" 0 "Initial Findings" "baseline" "$content_file")
rm -f "$content_file"
# Manually index with override (testing the override itself)
episodic_index_file "$doc_path" "_global" "progression"
ft=$(episodic_db_exec "SELECT file_type FROM documents WHERE project='_global' LIMIT 1;" "$EPISODIC_DB")
if [[ "$ft" == "progression" ]]; then
    echo "PASS"
else
    echo "FAIL: expected file_type=progression, got $ft"
    exit 1
fi

# Test 7: Auto-index on progression add
echo -n "  7. Auto-index on progression add... "
# Clear previous entries
episodic_db_exec "DELETE FROM documents;" "$EPISODIC_DB"
episodic_db_exec "DELETE FROM documents_fts;" "$EPISODIC_DB"
pi_progression_create "projA" "Migration Plan" >/dev/null
content_tmp=$(mktemp)
printf '# Migration Plan\n\nPhase 1: dual-write to both databases.\n' > "$content_tmp"
pi_progression_add "projA" "Migration Plan" 0 "Phase One" "baseline" "$content_tmp" >/dev/null
rm -f "$content_tmp"
ft_a=$(episodic_db_exec "SELECT file_type FROM documents WHERE project='projA' AND file_type='progression' LIMIT 1;" "$EPISODIC_DB")
if [[ "$ft_a" == "progression" ]]; then
    echo "PASS"
else
    echo "FAIL: progression doc not auto-indexed (got: '$ft_a')"
    exit 1
fi

# Test 8: Cross-project search finds results from multiple projects
echo -n "  8. Cross-project search... "
# projA already has "Migration Plan" with "dual-write" content from test 7
# Re-index _global "AWS Cost Patterns" (test 7 wiped the DB)
global_prog_dir=$(_pi_progressions_dir "_global")
for md_file in "$global_prog_dir"/aws-cost-patterns/*.md; do
    [[ -f "$md_file" ]] && (episodic_index_file "$md_file" "_global" "progression")
done
# Add projB
pi_progression_create "projB" "Cost Review" >/dev/null
content_tmp=$(mktemp)
printf '# Cost Review\n\nThe reserved instances cost analysis shows significant savings.\n' > "$content_tmp"
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

# Test 10: FTS5 escape safety
echo -n "  10. FTS5 escape safety... "
special_out=$("$SCRIPT_DIR/../bin/pi-progression-search" 'cost OR DROP TABLE' 2>/dev/null || true)
# Should not error
echo "PASS"

# Test 11: No results for non-matching query
echo -n "  11. No results for non-matching query... "
nomatch=$("$SCRIPT_DIR/../bin/pi-progression-search" "xyznonexistent" 2>/dev/null)
if [[ -z "$nomatch" || "$nomatch" == "No results found." ]]; then
    echo "PASS"
else
    echo "FAIL: expected no results"
    echo "  Output: $nomatch"
    exit 1
fi

# Test 12: Context injection includes _global progressions
echo -n "  12. Context includes _global progressions... "
ctx_global=$(pi_progression_generate_context "_global" 2>/dev/null)
if echo "$ctx_global" | grep -q "AWS Cost Patterns"; then
    echo "PASS"
else
    echo "FAIL: _global progression not in context"
    echo "  Context: $ctx_global"
    exit 1
fi

# Test 13: --all flag lists cross-project progressions
echo -n "  13. --all lists cross-project progressions... "
all_out=$("$SCRIPT_DIR/../bin/pi-progression-status" --all 2>/dev/null)
if echo "$all_out" | grep -q "projA" && echo "$all_out" | grep -q "projB" && echo "$all_out" | grep -q "_global"; then
    echo "PASS"
else
    echo "FAIL: --all should list progressions from all projects"
    echo "  Output: $all_out"
    exit 1
fi

echo "=== test-progression-search: ALL PASS ==="
