#!/usr/bin/env bash
set -euo pipefail

# tests/test-boards.sh
# Simple smoke tests for scripts/lib/boards.sh

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)

if [ ! -f "$ROOT_DIR/scripts/lib/boards.sh" ]; then
  echo "ERROR: helper not found at $ROOT_DIR/scripts/lib/boards.sh"
  exit 1
fi

# shellcheck source=/dev/null
source "$ROOT_DIR/scripts/lib/boards.sh"

echo "Running tests for boards helper..."

# Test 1: boards_list returns something
if ! BOARDS=$(boards_list 2>/dev/null); then
  echo "FAIL: boards_list returned non-zero"
  exit 1
fi

if [ -z "$(echo "$BOARDS" | tr -d '[:space:]')" ]; then
  echo "FAIL: boards_list is empty"
  exit 1
fi

echo "PASS: boards_list returned:"
echo "$BOARDS" | sed 's/^/  - /'

# Test 2: every config file maps to a listed board and validates
FAILED=0
for f in "$ROOT_DIR"/boards/*.conf.sh; do
  [ -e "$f" ] || continue
  base=$(basename "$f")
  b=${base%.conf.sh}

  if ! echo "$BOARDS" | grep -qx "$b"; then
    echo "FAIL: boards_list missing expected board '$b' (from $f)"
    FAILED=1
    continue
  fi

  if ! boards_validate "$b"; then
    echo "FAIL: boards_validate returned non-zero for '$b'"
    FAILED=1
  else
    echo "PASS: boards_validate '$b'"
  fi

  desc=$(boards_description "$b" || true)
  if [ -z "$desc" ]; then
    echo "WARN: boards_description empty for '$b' (consider adding a DESCRIPTION comment)"
  else
    echo "PASS: description for $b: $desc"
  fi
done

# Test 3: a listed board resolves its config vars (exercises source-in-subshell path)
first_board=$(echo "$BOARDS" | head -n1)
if [ -n "$first_board" ]; then
  if armbian=$(boards_armbian "$first_board") && [ -n "$armbian" ]; then
    echo "PASS: boards_armbian $first_board -> $armbian"
  else
    echo "FAIL: boards_armbian returned empty for '$first_board'"
    FAILED=1
  fi
fi

# Test 4: invalid board should fail validation
if boards_validate "no-such-board"; then
  echo "FAIL: boards_validate unexpectedly succeeded for 'no-such-board'"
  exit 1
else
  echo "PASS: boards_validate rejects unknown board"
fi

if [ "$FAILED" -eq 1 ]; then
  echo "One or more tests FAILED"
  exit 1
fi

echo "All tests passed"
exit 0

