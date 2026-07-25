#!/usr/bin/env bash
# Construction harness: deterministic architecture-conformance gate for Go services.
# Zero LLM tokens. Universal invariants fail the gate (ERROR); objective-varying
# concerns advise only (WARN). Run at scaffold time and after each build phase.
#
# Usage: conformance.sh [REPO_ROOT]   (defaults to current directory)
# Exit:  0 = no ERROR   1 = at least one ERROR

set -u

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "cannot cd into $ROOT"; exit 2; }

ERRORS=0
WARNS=0

err()  { ERRORS=$((ERRORS+1)); printf 'ERROR  %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/         /'; }
warn() { WARNS=$((WARNS+1));  printf 'WARN   %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/         /'; }
pass() { printf 'PASS   %s\n' "$1"; }

has() { command -v "$1" >/dev/null 2>&1; }
imports() { grep -rqE "$1" --include='*.go' internal cmd pkg 2>/dev/null; }

[ -d internal/app ] || { echo "no internal/app — not a domain service layout; nothing to check"; exit 0; }

echo "== Construction harness :: $(basename "$(pwd)") =="

# ---------------------------------------------------------------------------
# UNIVERSAL INVARIANTS (ERROR)
# ---------------------------------------------------------------------------

# U1 base wiring: bootstrap package
if [ -d internal/bootstrap ]; then pass "U1 internal/bootstrap present (base wiring)"
else err "U1 missing internal/bootstrap (base wiring layer)"; fi

# U2 DI/composition: modules pattern OR fx
if ls cmd/*/modules >/dev/null 2>&1 || imports 'go\.uber\.org/fx'; then
  pass "U2 composition wiring present (cmd/*/modules or fx)"
else err "U2 no composition layer (expected cmd/{app}/modules or uber/fx)"; fi

# U3 each domain has a domain/ layer
missing_domain=""
for d in internal/app/*/; do
  [ -d "$d" ] || continue
  [ -d "${d}domain" ] || missing_domain="${missing_domain}${d}\n"
done
if [ -z "$missing_domain" ]; then pass "U3 every internal/app/{domain} has domain/"
else err "U3 domain(s) without a domain/ layer" "$(printf '%b' "$missing_domain")"; fi

# U4 use case is per-operation (no *.go directly under usecase/)
mono_uc=""
for d in internal/app/*/usecase; do
  [ -d "$d" ] || continue
  hits=$(ls "$d"/*.go 2>/dev/null)
  [ -n "$hits" ] && mono_uc="${mono_uc}${hits}\n"
done
if [ -z "$mono_uc" ]; then pass "U4 use cases are per-operation (usecase/{op}/)"
else err "U4 monolithic use case file(s) directly under usecase/ (split into usecase/{op}/)" "$(printf '%b' "$mono_uc")"; fi

# U5 handlers are per-operation (no *.go directly under handler/)
mono_h=""
for d in internal/app/*/handler; do
  [ -d "$d" ] || continue
  hits=$(ls "$d"/*.go 2>/dev/null)
  [ -n "$hits" ] && mono_h="${mono_h}${hits}\n"
done
if [ -z "$mono_h" ]; then pass "U5 handlers are per-operation (handler/{op}/)"
else err "U5 monolithic handler file(s) directly under handler/ (split into handler/{op}/)" "$(printf '%b' "$mono_h")"; fi

# U6 handler must use the concrete use case — never a handler-local interface
hits=$(grep -rnE --include='handler.go' '^[[:space:]]*(type[[:space:]]+)?(service|useCase|UseCase)[[:space:]]+interface[[:space:]]*\{' internal/app 2>/dev/null)
if [ -z "$hits" ]; then pass "U6 handlers hold the concrete use case (no handler-local interface)"
else err "U6 handler-local interface (wrong-layer mocking; use the concrete use case)" "$hits"; fi

# U7 no hand-written test doubles — mocks come from mockery
hits=$(grep -rnE --include='*_test.go' '^[[:space:]]*(type[[:space:]]+)?(fake|stub|mock)[A-Za-z0-9_]*[[:space:]]+struct[[:space:]]*\{' internal/app 2>/dev/null)
if [ -z "$hits" ]; then pass "U7 no hand-written fakes/stubs in tests (mockery only)"
else err "U7 hand-written test double(s); generate mocks with mockery" "$hits"; fi

# U8 handler tests assert whole objects vs golden testdata — no field-by-field float asserts
hits=$(grep -rlnE --include='*_test.go' 'InDelta|InEpsilon' internal/app/*/handler 2>/dev/null)
if [ -z "$hits" ]; then pass "U8 handler tests assert whole objects (no field-by-field float asserts)"
else err "U8 field-by-field float assert(s) in handler tests; assert whole object vs golden testdata" "$hits"; fi

# U9 no gock / http.Transport monkeypatching — use the httptest upstream stub
if imports '(h2non/gock|gopkg\.in/gock)'; then
  err "U9 gock detected; use the httptest-based upstream stub (modern, dependency-free interception)"
else pass "U9 no gock/transport monkeypatching"; fi

# U10 handlers self-register routes; modules never hardcode route strings
missing_reg=""
while IFS= read -r hf; do
  [ -n "$hf" ] || continue
  grep -qE '^[[:space:]]*func[[:space:]]+RegisterRoutes[[:space:]]*\(' "$hf" || missing_reg="${missing_reg}${hf}\n"
done < <(find internal/app/*/handler -mindepth 2 -name 'handler.go' 2>/dev/null)
hardcoded=$(grep -rnE '\br\.(Get|Post|Put|Patch|Delete|Head|Options)\(' --include='*.go' cmd/*/modules 2>/dev/null)
if [ -z "$missing_reg" ] && [ -z "$hardcoded" ]; then
  pass "U10 handlers expose RegisterRoutes and modules hardcode no routes"
else
  [ -n "$missing_reg" ] && err "U10 handler(s) without func RegisterRoutes (route must live next to its handler)" "$(printf '%b' "$missing_reg")"
  [ -n "$hardcoded" ] && err "U10 module hardcodes route string(s); call each handler.RegisterRoutes instead" "$hardcoded"
fi

# ---------------------------------------------------------------------------
# OBJECTIVE-VARYING CONCERNS (WARN — checked only when detected)
# ---------------------------------------------------------------------------

# W1 mockery config present when mockable interfaces exist
if grep -rqE 'usecase' --include='*.go' internal/app 2>/dev/null; then
  if [ -f .mockery.yaml ] || [ -f .mockery.yml ]; then pass "W1 mockery config present"
  else warn "W1 no .mockery.yaml (test doubles should be generated, not hand-written)"; fi
fi

# W2 router / middleware baseline
if [ -d internal/bootstrap ]; then
  if grep -rqE 'go-chi/chi' --include='*.go' internal 2>/dev/null; then
    if grep -rqE '\.Use\(' --include='*.go' internal/bootstrap 2>/dev/null; then pass "W2 chi router + middleware chain wired"
    else warn "W2 chi present but no middleware chain (r.Use(...)) in bootstrap"; fi
  else warn "W2 no chi router detected in internal (confirm router choice is intentional)"; fi
fi

# W3 structured logger present
if imports '(pkg/logger|/internal/.*logger|log/slog|uber-go/zap|rs/zerolog)'; then pass "W3 structured logger present"
else warn "W3 no structured logger detected (slog/zap/zerolog/pkg logger)"; fi

# W4 external HTTP client → expect an integration/e2e upstream-stub suite
if grep -rqE 'http\.(Client|Get|Post|NewRequest)' --include='*.go' internal 2>/dev/null; then
  if find internal cmd test -type d \( -name 'e2e' -o -name '*suite*' -o -path '*testing/integration*' \) 2>/dev/null | grep -q .; then
    pass "W4 external HTTP client + integration/upstream-stub suite present"
  else warn "W4 external HTTP client but no e2e/upstream-stub suite (add httptest upstream stub + golden fixtures)"; fi
fi

# W5 database → expect fixtures + integration-tagged tests
if imports '(gorm\.io/gorm|database/sql|jackc/pgx|jmoiron/sqlx)'; then
  fixtures=$(find . -type d -name 'fixtures' 2>/dev/null | grep -q . && echo yes)
  inttests=$(grep -rlq '//go:build integration' --include='*_test.go' . 2>/dev/null && echo yes)
  if [ "$fixtures" = yes ] && [ "$inttests" = yes ]; then pass "W5 database + YAML fixtures + integration tests present"
  else warn "W5 database detected but missing fixtures dir and/or //go:build integration repository tests"; fi
fi

# W6 testdata factory package alongside test packages
notd=""
while IFS= read -r td; do
  [ -n "$td" ] || continue
  [ -d "$td/testdata" ] || [ -d "$(dirname "$td")/testdata" ] || notd="${notd}${td}\n"
done < <(grep -rl --include='*_test.go' '' internal/app 2>/dev/null | while read -r f; do dirname "$f"; done | sort -u)
if [ -z "$notd" ]; then pass "W6 test packages have a testdata/ factory package"
else warn "W6 test package(s) without a testdata/ factory (mandatory testdata rule)" "$(printf '%b' "$notd")"; fi

# W7 API contract: OpenAPI spec under docs/, and no endpoint table in README
if find internal/app -type f -name 'handler.go' 2>/dev/null | grep -q .; then
  if find docs -type f \( -iname 'openapi.*' -o -iname '*.openapi.*' \) 2>/dev/null | grep -q .; then
    pass "W7 OpenAPI spec present under docs/"
  else warn "W7 HTTP handlers but no OpenAPI spec under docs/ (document the API as OpenAPI, not a README table)"; fi
  if [ -f README.md ] && grep -qE '^\|[[:space:]]*(GET|POST|PUT|PATCH|DELETE)[[:space:]]*\|' README.md 2>/dev/null; then
    warn "W7 README has an HTTP endpoint table (move the API contract to the docs/ OpenAPI spec)"
  fi
fi

# W8 full-stack layout: frontend self-contained under web/, not at repo root
if [ -f package.json ]; then
  warn "W8 package.json at repo root — a browser frontend must be self-contained under web/ (web/app source, web/static generated)"
elif [ -f web/package.json ]; then pass "W8 frontend self-contained under web/"; fi

# W9 error mapping centralized per domain — no per-operation errormapping file
if find internal/app -type f \( -name 'errormapping.go' -o -name 'error_mapping.go' \) -path '*/handler/*/*' 2>/dev/null | grep -q .; then
  warn "W9 per-operation error-mapping file found under handler/{op}/ — centralize one Mapping per domain and render via pkg/httperror"
elif find internal/app -type f -name 'handler.go' 2>/dev/null | grep -q .; then
  pass "W9 no per-operation error mapping (centralized per domain)"
fi

# ---------------------------------------------------------------------------
echo "== Summary: ${ERRORS} error(s), ${WARNS} warning(s) =="
[ "$ERRORS" -eq 0 ]
