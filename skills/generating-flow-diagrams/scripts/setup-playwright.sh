#!/usr/bin/env bash
# Installs Playwright and Chromium into a throwaway directory, outside any repo.
# Usage: setup-playwright.sh [dir]   (default: ${TMPDIR:-/tmp}/flow-diagrams-playwright)
# Prints the path to pass to capture.mjs as --playwright.
set -euo pipefail
dir="${1:-${TMPDIR:-/tmp}/flow-diagrams-playwright}"
mkdir -p "$dir"
cd "$dir"
[[ -f package.json ]] || npm init -y >/dev/null
npm install playwright >/dev/null
npx playwright install chromium >/dev/null
echo "$dir/node_modules/playwright"
