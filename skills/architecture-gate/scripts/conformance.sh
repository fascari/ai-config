#!/usr/bin/env bash
# Construction harness: deterministic architecture-conformance gate for Go
# services. Zero LLM tokens. Universal invariants fail the gate (ERROR);
# objective-varying concerns advise only (WARN). Run at scaffold time and
# after each build phase.
#
# Go backend only. There is no React/frontend conformance gate here — the
# only frontend-aware check (W8, in checks-frontend.sh) confirms a browser
# frontend is placed under web/, it does not validate frontend code quality.
#
# Checks are split across sibling scripts so no single file grows unbounded:
#   lib.sh              shared helpers (err/warn/pass, has, imports)
#   checks-universal.sh U1-U10, ERROR tier
#   checks-objective.sh W1-W7 + W9, WARN tier, Go backend
#   checks-frontend.sh  W8, WARN tier, frontend repo-layout only
#
# Usage: conformance.sh [REPO_ROOT]   (defaults to current directory)
# Exit:  0 = no ERROR   1 = at least one ERROR

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "cannot cd into $ROOT"; exit 2; }

ERRORS=0
WARNS=0

# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

[ -d internal/app ] || { echo "no internal/app — not a domain service layout; nothing to check"; exit 0; }

echo "== Construction harness :: $(basename "$(pwd)") =="

# shellcheck source=checks-universal.sh
. "$SCRIPT_DIR/checks-universal.sh"
# shellcheck source=checks-objective.sh
. "$SCRIPT_DIR/checks-objective.sh"
# shellcheck source=checks-frontend.sh
. "$SCRIPT_DIR/checks-frontend.sh"

echo "== Summary: ${ERRORS} error(s), ${WARNS} warning(s) =="
[ "$ERRORS" -eq 0 ]
