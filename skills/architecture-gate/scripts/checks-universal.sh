#!/usr/bin/env bash
# Universal invariants (U1-U10) — always enforced, fail the gate (ERROR).
# Sourced by conformance.sh after lib.sh; expects ROOT already cd'ed into,
# and err()/warn()/pass()/imports() already defined. Not meant to be run
# directly.

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
