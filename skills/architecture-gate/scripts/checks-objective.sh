#!/usr/bin/env bash
# Objective-varying concerns (W1-W7, W9) — Go backend only. Advise (WARN),
# never fail the gate; checked only when the objective actually uses the
# concern (router, logger, DI, DB, external HTTP, testdata, API contract,
# error mapping). Sourced by conformance.sh after checks-universal.sh; expects
# ROOT already cd'ed into, and err()/warn()/pass()/imports() already defined.
# Not meant to be run directly.
#
# Frontend/React checks live in checks-frontend.sh, not here — this file is
# Go-only.

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

# W4 external HTTP client → expect a correctly placed, tagged e2e suite
if grep -rqE 'http\.(Client|Get|Post|NewRequest)' --include='*.go' internal 2>/dev/null; then
  misplaced=$(find internal cmd -type d -name 'e2e' 2>/dev/null | grep -vE '/test/e2e$')
  placed=$(find internal/app -type d -path '*/test/e2e/*' 2>/dev/null)
  harness=$(find internal/testing -type d -path '*integration*' 2>/dev/null)
  untagged=$(find internal/app -path '*/test/e2e/*' -name '*_test.go' 2>/dev/null | while IFS= read -r f; do
    head -1 "$f" | grep -q 'go:build integration' || printf '%s\n' "$f"
  done)
  if [ -n "$misplaced" ]; then
    warn "W4 e2e package misplaced; move it under internal/app/{domain}/test/e2e/{operation}" "$misplaced"
  elif [ -z "$placed" ] || [ -z "$harness" ]; then
    warn "W4 external HTTP client but no per-operation e2e suite (expected internal/app/*/test/e2e/{operation} + internal/testing/integration harness)"
  elif [ -n "$untagged" ]; then
    warn "W4 e2e test file(s) missing //go:build integration" "$untagged"
  else
    pass "W4 external HTTP client + per-operation e2e suite (correct location, tagged) present"
  fi
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

# W9 error mapping centralized per domain — no per-operation errormapping file
if find internal/app -type f \( -name 'errormapping.go' -o -name 'error_mapping.go' \) -path '*/handler/*/*' 2>/dev/null | grep -q .; then
  warn "W9 per-operation error-mapping file found under handler/{op}/ — centralize one Mapping per domain and render via pkg/httperror"
elif find internal/app -type f -name 'handler.go' 2>/dev/null | grep -q .; then
  pass "W9 no per-operation error mapping (centralized per domain)"
fi
