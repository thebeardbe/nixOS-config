#!/usr/bin/env bash
# godfiles: list source files over the size budget. Stack-agnostic. Read-only.
# Usage: godfiles.sh [repo-root]
# Env: PI_FILE_SOFT_LINES (default 600), PI_FILE_HARD_LINES (default 1000)
set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "cannot cd to $ROOT"; exit 0; }

SOFT="${PI_FILE_SOFT_LINES:-600}"
HARD="${PI_FILE_HARD_LINES:-1000}"

EXTS='py|pyi|js|jsx|mjs|cjs|ts|tsx|go|rb|rs|java|kt|kts|cs|php|swift|scala|c|cc|cpp|h|hpp|vue|svelte|dart|lua|ex|exs|sh|ps1|sql'

# Paths we never flag (vendor/generated/tests/fixtures/lockfiles/minified).
SKIP='(^|/)(node_modules|vendor|dist|build|\.git|\.venv|__pycache__|\.pytest_cache|target|coverage|generated|migrations|__snapshots__|fixtures)(/|$)|\.min\.|\.lock$|\.d\.ts$|\.generated\.|\.g\.dart$|\.freezed\.dart$|_pb2\.py$|\.pb\.go$'

# Test/spec files are reported by the guard's warn-only rule, not as GOD/WARN.
TEST='(^|/)(test|tests|__tests__|spec|specs)/|(^|/)(test|tests|__tests__|spec|specs)$|(^|/)(test_|spec_)[^/]*$|\.(test|spec)\.[a-z0-9]+$|_test\.[a-z0-9]+$|(^|/)conftest\.py$|(^|/)__mocks__/|\.feature$|(^|/)[^/]*(Test|Tests|Spec|IT)\.(java|kt|kts|scala|groovy|cs|fs|vb|php)$'

if git rev-parse --git-dir >/dev/null 2>&1; then
  FILES=$(git ls-files --cached --others --exclude-standard 2>/dev/null)
else
  FILES=$(find . -type f 2>/dev/null | sed 's|^\./||')
fi

printf 'godfiles - %s  (soft=%s hard=%s)\n\n' "$(pwd)" "$SOFT" "$HARD"
echo "$FILES" | grep -E "\.($EXTS)$" | grep -vE "$SKIP" | grep -viE "$TEST" | while IFS= read -r f; do
  [ -f "$f" ] || continue
  n=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
  [ -n "$n" ] || continue
  if [ "$n" -gt "$HARD" ]; then
    printf 'GOD  %6s  %s\n' "$n" "$f"
  elif [ "$n" -gt "$SOFT" ]; then
    printf 'WARN %6s  %s\n' "$n" "$f"
  fi
done | sort -k2 -rn

echo
echo "GOD = must split before adding more. WARN = plan a split."
