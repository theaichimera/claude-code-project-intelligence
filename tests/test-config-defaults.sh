#!/usr/bin/env bash
# test-config-defaults.sh: Verify config defaults are consistent after sourcing all modules
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export EPISODIC_DB="/tmp/episodic-test-$$.db"
export EPISODIC_LOG="/tmp/episodic-test-$$.log"

# Unset any env overrides to test pure defaults
unset EPISODIC_SUMMARY_MODEL EPISODIC_CONTEXT_COUNT 2>/dev/null || true

# Source config (the single source of truth)
source "$SCRIPT_DIR/../lib/config.sh"

cleanup() { rm -f "$EPISODIC_DB" "$EPISODIC_LOG"; }
trap cleanup EXIT

echo "=== test-config-defaults ==="

# Test 1: EPISODIC_SUMMARY_MODEL should be opus 4.5
echo -n "  1. EPISODIC_SUMMARY_MODEL default... "
if [[ "$EPISODIC_SUMMARY_MODEL" == "claude-opus-4-5-20251101" ]]; then
    echo "PASS ($EPISODIC_SUMMARY_MODEL)"
else
    echo "FAIL: expected claude-opus-4-5-20251101, got $EPISODIC_SUMMARY_MODEL"
    exit 1
fi

# Test 2: EPISODIC_CONTEXT_COUNT should be 3
echo -n "  2. EPISODIC_CONTEXT_COUNT default... "
if [[ "$EPISODIC_CONTEXT_COUNT" == "3" ]]; then
    echo "PASS ($EPISODIC_CONTEXT_COUNT)"
else
    echo "FAIL: expected 3, got $EPISODIC_CONTEXT_COUNT"
    exit 1
fi

# Test 3: Env override still works
echo -n "  3. Env override takes precedence... "
(
    export EPISODIC_SUMMARY_MODEL="custom-model"
    source "$SCRIPT_DIR/../lib/config.sh"
    if [[ "$EPISODIC_SUMMARY_MODEL" == "custom-model" ]]; then
        echo "PASS"
    else
        echo "FAIL: override not respected, got $EPISODIC_SUMMARY_MODEL"
        exit 1
    fi
)

echo "=== test-config-defaults: ALL PASS ==="
