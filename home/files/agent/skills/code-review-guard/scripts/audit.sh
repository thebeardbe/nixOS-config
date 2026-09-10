#!/usr/bin/env bash
# code-review-guard audit: fast, stack-agnostic smell scan for a repo.
# Read-only. Always exits 0 so it can run as a report step.
#
# In a git repo it scans tracked + untracked-not-ignored files (so vendored
# checkouts, node_modules, build output and .gitignore'd junk are skipped).
# `vendor/` paths are excluded by default (upstream code is not ours to fix).
# Outside a git repo it falls back to a filtered recursive scan.
#
# Usage: ./audit.sh [repo-root]
# Env:   PI_FILE_SOFT_LINES (600), PI_FILE_HARD_LINES (1000) for the size check.
set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "cannot cd to $ROOT"; exit 0; }

SOFT="${PI_FILE_SOFT_LINES:-600}"
HARD="${PI_FILE_HARD_LINES:-1000}"

HAVE_GIT=0
git rev-parse --git-dir >/dev/null 2>&1 && HAVE_GIT=1

# Source globs across common stacks.
SRC=('*.py' '*.pyi' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' '*.go' '*.rb'
     '*.rs' '*.java' '*.kt' '*.kts' '*.cs' '*.php' '*.swift' '*.scala' '*.c'
     '*.cc' '*.cpp' '*.h' '*.hpp' '*.vue' '*.svelte' '*.dart' '*.lua' '*.ex'
     '*.exs' '*.sh' '*.ps1' '*.sql')

EXCL=(':(exclude)vendor/**' ':(exclude)**/vendor/**'
      ':(exclude)node_modules/**' ':(exclude)**/node_modules/**'
      ':(exclude)dist/**' ':(exclude)**/dist/**'
      ':(exclude)build/**' ':(exclude)**/build/**'
      ':(exclude)generated/**' ':(exclude)**/generated/**'
      ':(exclude)coverage/**' ':(exclude)**/coverage/**'
      ':(exclude).venv/**' ':(exclude)**/.venv/**')

hdr() { printf '\n== %s ==\n' "$1"; }
list() { sed 's/^/  /' | head -25; }

# g <ere> [pathspec...] -> matching lines ("file:line:..."). Defaults to SRC.
g() {
  local re="$1"; shift
  if [ "$#" -eq 0 ]; then set -- "${SRC[@]}"; fi
  if [ "$HAVE_GIT" = 1 ]; then
    git grep -n --untracked -I -E -e "$re" -- "$@" "${EXCL[@]}" 2>/dev/null
  else
    grep -rn -I -E -e "$re" --exclude-dir=node_modules --exclude-dir=.git \
      --exclude-dir=vendor --exclude-dir=dist --exclude-dir=build \
      --exclude-dir=.venv --exclude-dir=__pycache__ --exclude-dir=.pytest_cache \
      --exclude-dir=target --exclude-dir=coverage --exclude-dir=generated . 2>/dev/null
  fi
}

echo "code-review-guard audit - $(pwd)  ($([ "$HAVE_GIT" = 1 ] && echo 'git: tracked+untracked' || echo 'filesystem'))"

hdr "1. Swallowed errors (Python except->pass/continue, empty JS/TS catch)"
if [ "$HAVE_GIT" = 1 ]; then
  git grep -n --untracked -I -A1 -E -e '^[[:space:]]*except[^:]*:[[:space:]]*$' -- '*.py' "${EXCL[@]}" 2>/dev/null \
    | grep -B1 -E '^[^:]*[0-9]+[-:][[:space:]]*(pass|continue)[[:space:]]*$' | grep 'except' | list
  g 'catch[[:space:]]*(\([^)]*\))?[[:space:]]*\{[[:space:]]*\}|\.catch\([[:space:]]*\([[:space:]]*\)[[:space:]]*=>[[:space:]]*\{[[:space:]]*\}' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.ts' '*.tsx' '*.vue' '*.svelte' | list
else
  g 'except[^:]*:[[:space:]]*$' '*.py' | list
fi

hdr "2. SQL: SELECT *"
g 'select[[:space:]]+\*' | list || echo "  (none)"

hdr "3. SQL: string-built queries (interpolation / format / concatenation)"
g '(execute|query|raw)\([[:space:]]*f["'"'"']|(execute|query|raw)\([^)]*%[[:space:]]*\(|(execute|query|raw)\([^)]*\.format\(|(execute|query|raw)\([^)]*\+' | list || echo "  (none)"

hdr "4. Hardcoded secret values (heuristic)"
g '(password|passwd|secret|api[_-]?key|token|client[_-]?secret)[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"']{6,}["'"'"']' \
  | grep -viE 'example|placeholder|change-me|test-|dummy|xxx|\$\{|process\.env|os\.environ|password_hash|ADMIN_PASS|import\.meta' | list || echo "  (none)"

hdr "5. Magic numbers in comparisons (sample; review manually)"
g '(==|===|<=|>=|<|>)[[:space:]]*[0-9]{3,}' | grep -viE 'test_|#|//|version|range\(|0x' | list || echo "  (none)"

hdr "6. Scratch / debug files"
FILES=""
if [ "$HAVE_GIT" = 1 ]; then
  FILES=$(git ls-files --cached --others --exclude-standard 2>/dev/null \
    | grep -vE '(^|/)(vendor|node_modules|dist|build|\.venv|__pycache__|\.pytest_cache|coverage|generated)/')
else
  FILES=$(find . -type f 2>/dev/null | sed 's|^\./||')
fi
echo "$FILES" | grep -E '(^|/)_[^/_][^/]*\.(py|js|ts|sh)$|_scratch|\.orig$|\.rej$|(^|/)debug[^/]*\.(py|js|ts)$' | list || echo "  (none)"

hdr "7. Leftover markers"
g '^(<<<<<<<|>>>>>>>|=======)$|FIXME|XXX|breakpoint\(\)|pdb\.set_trace|debugger;|print\("DEBUG|console\.log\("debug' | list || echo "  (none)"

hdr "8. Oversized source files (soft=$SOFT hard=$HARD)"
GODFILES="$HOME/.pi/agent/skills/god-file-guard/scripts/godfiles.sh"
if [ -x "$GODFILES" ]; then
  # Single source of truth for the size scan (also used by the /godfiles command).
  PI_FILE_SOFT_LINES="$SOFT" PI_FILE_HARD_LINES="$HARD" bash "$GODFILES" . 2>/dev/null \
    | grep -E '^(GOD|WARN)[[:space:]]+[0-9]' | list || echo "  (none)"
else
  echo "  (godfiles.sh not found; install the god-file-guard skill)"
fi

hdr "9. Em-dash in copy (U+2014)"
g $'\u2014' '*.py' '*.js' '*.jsx' '*.ts' '*.tsx' '*.vue' '*.svelte' '*.html' '*.ejs' | list || echo "  (none)"

echo
echo "Review 1-3 as correctness issues; 4-5 as hardening; 6-9 as hygiene."
echo "This scan is heuristics, not a substitute for reading the diff."
