#!/usr/bin/env bash
# test-deep-dive.sh: Test deep-dive library functions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DB="/tmp/episodic-test-deep-dive-$$.db"
TEST_KNOWLEDGE="/tmp/episodic-test-knowledge-deep-dive-$$"
TEST_PROJECT="/tmp/episodic-test-project-$$"

# Override config
export EPISODIC_DB="$TEST_DB"
export EPISODIC_LOG="/tmp/episodic-test-deep-dive-$$.log"
export EPISODIC_KNOWLEDGE_DIR="$TEST_KNOWLEDGE"

source "$SCRIPT_DIR/../lib/deep-dive.sh"

cleanup() {
    rm -f "$TEST_DB" "$EPISODIC_LOG"
    rm -rf "$TEST_KNOWLEDGE" "$TEST_PROJECT"
}
trap cleanup EXIT

echo "=== test-deep-dive ==="

# Set up a mock project directory
mkdir -p "$TEST_PROJECT/src"
cat > "$TEST_PROJECT/package.json" <<'EOF'
{
  "name": "test-widget",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.0",
    "pg": "^8.11.0"
  },
  "scripts": {
    "start": "node src/index.js",
    "test": "jest"
  }
}
EOF

cat > "$TEST_PROJECT/README.md" <<'EOF'
# Test Widget

A sample widget application for testing deep-dive context collection.

## Getting Started
Run `npm install` then `npm start`.
EOF

cat > "$TEST_PROJECT/src/index.js" <<'EOF'
const express = require('express');
const app = express();

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.listen(3000, () => console.log('Server running on port 3000'));
EOF

cat > "$TEST_PROJECT/Dockerfile" <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
CMD ["node", "src/index.js"]
EOF

mkdir -p "$TEST_KNOWLEDGE"

# Test 1: Context collection finds manifests
echo -n "  1. Context collection finds manifests... "
ctx=$(episodic_deep_dive_collect_context "$TEST_PROJECT")
if echo "$ctx" | grep -q "package.json" && echo "$ctx" | grep -q "express"; then
    echo "PASS"
else
    echo "FAIL: manifest content not found in context"
    exit 1
fi

# Test 2: Context collection finds entry points
echo -n "  2. Context collection finds entry points... "
if echo "$ctx" | grep -q "Entry Point" && echo "$ctx" | grep -q "express"; then
    echo "PASS"
else
    echo "FAIL: entry points not found in context"
    exit 1
fi

# Test 3: Context collection finds README
echo -n "  3. Context collection finds README... "
if echo "$ctx" | grep -q "Test Widget"; then
    echo "PASS"
else
    echo "FAIL: README content not found in context"
    exit 1
fi

# Test 4: Context collection finds Dockerfile
echo -n "  4. Context collection finds Dockerfile... "
if echo "$ctx" | grep -q "node:20-alpine"; then
    echo "PASS"
else
    echo "FAIL: Dockerfile content not found in context"
    exit 1
fi

# Test 5: Exists check (false)
echo -n "  5. Exists check returns false when no deep-dive... "
if ! episodic_deep_dive_exists "test-widget"; then
    echo "PASS"
else
    echo "FAIL: exists returned true for non-existent deep-dive"
    exit 1
fi

# Test 6: Write deep-dive
echo -n "  6. Write deep-dive... "
episodic_deep_dive_write "test-widget" "# Test Widget — Deep Dive

## Overview
A sample widget application.

## Tech Stack
- Node.js
- Express
- PostgreSQL" "$TEST_PROJECT" "test-model"
if [[ -f "$TEST_KNOWLEDGE/test-widget/deep-dive.md" ]]; then
    echo "PASS"
else
    echo "FAIL: deep-dive.md not written"
    exit 1
fi

# Test 7: Exists check (true)
echo -n "  7. Exists check returns true after write... "
if episodic_deep_dive_exists "test-widget"; then
    echo "PASS"
else
    echo "FAIL: exists returned false for existing deep-dive"
    exit 1
fi

# Test 8: Read strips frontmatter
echo -n "  8. Read strips YAML frontmatter... "
body=$(episodic_deep_dive_read "test-widget")
if echo "$body" | grep -q "Test Widget" && ! echo "$body" | grep -q "^type: deep-dive"; then
    echo "PASS"
else
    echo "FAIL: frontmatter not stripped or body missing"
    echo "  Body: $(echo "$body" | head -5)"
    exit 1
fi

# Test 9: YAML frontmatter fields present
echo -n "  9. YAML frontmatter has required fields... "
frontmatter=$(sed -n '/^---$/,/^---$/p' "$TEST_KNOWLEDGE/test-widget/deep-dive.md")
has_type=$(echo "$frontmatter" | grep -c "type: deep-dive" || true)
has_project=$(echo "$frontmatter" | grep -c "project: test-widget" || true)
has_generated=$(echo "$frontmatter" | grep -c "generated:" || true)
has_model=$(echo "$frontmatter" | grep -c "model: test-model" || true)
has_path=$(echo "$frontmatter" | grep -c "project_path:" || true)
if [[ "$has_type" -ge 1 && "$has_project" -ge 1 && "$has_generated" -ge 1 && "$has_model" -ge 1 && "$has_path" -ge 1 ]]; then
    echo "PASS"
else
    echo "FAIL: missing frontmatter fields (type=$has_type project=$has_project generated=$has_generated model=$has_model path=$has_path)"
    exit 1
fi

echo "=== test-deep-dive: ALL PASS ==="
