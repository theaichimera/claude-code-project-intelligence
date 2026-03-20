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

echo "=== test-progression-search: ALL PASS ==="
