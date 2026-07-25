---
name: validating-manual-flow
description: Use when implementation is complete and a manual-test-flow.md must be generated from an implementation plan to validate a running stack end to end. Triggers on "generate validation flow", "create test flow", "gerar fluxo de validacao", "manual validation", or when an implementation phase ends and manual end-to-end validation across the running services must be executed. Covers stack bring-up, fixture discovery from the running system, automated request execution, before/after state snapshots, and a final PASS/FAIL report.
---

# Validating manual flow

Reads an implementation plan, brings up the project's running stack, discovers
real fixtures from the live system, and generates `manual-test-flow.md`. When
executed fully, it fires the requests, snapshots system state before and after
each one, and produces a final PASS/FAIL report.

Vendor neutral: this skill hardcodes no service, port, database, credential, or
route. Every project-specific value (base URLs, auth, state-inspection
mechanism, service list, start commands) is discovered from the project's own
dev-env documentation and implementation plan, then recorded in a per-run Setup
table.

## When to use

- All implementation phases are complete and manual end-to-end validation must
  run against the actual running services.
- User says "generate validation flow", "create test flow", "run manual
  validation", "gerar fluxo de validacao".
- After the implementation, style, and architecture gates pass, before or
  alongside `reviewing-code`.
- When you need a ready-to-run script that brings the whole stack up (frontend
  plus backend plus any upstream simulator or dependency) and exercises it end
  to end before a live demo or a pairing session.

## Core protocol

The agent runs everything autonomously. There are no "user does X" steps. The
user triggers the skill and waits for the report.

```text
1. READ      -> implementation-plan.md: changed components, flows, acceptance criteria
2. CLARIFY   -> services, endpoints, and the state-inspection mechanism (plan + dev-env, or ask)
3. BRING UP  -> start each service the way dev-env documents; health-check every one first
4. DISCOVER  -> query the live system to find real fixtures (no hardcoded ids)
5. GENERATE  -> write manual-test-flow.md with scenarios + inspection queries + requests
6. EXECUTE   -> fire requests, snapshot state before/after, diff vs expected
7. REPORT    -> write PASS/FAIL report into the file's checklist
```

Steps 1-5 produce the file. Steps 6-7 execute it. If the user says "generate"
only, stop after step 5. If the user says "run", execute all seven steps.

## Output file location

Write to the plan folder, resolved the same way the orchestration skills resolve
it:

```
{plan_root}/{slug}/manual-test-flow.md
```

`{plan_root}` is `$AI_MEMORY_HOME/{project}/plans/`, reached via the repo's
`.plans` symlink. Never write to the session state folder or the repo root.

---

## Stack bring-up (step 3)

Real end-to-end validation requires the real services running. Discover how from
the project itself; never assume.

- Read the dev-env guide (for example `docs/guide/.../dev-env`, the README, a
  Makefile, a task runner config, or a compose file) to learn the start command
  for each service in the flow: frontend, backend, and any upstream simulator or
  dependency (which may be written in a different language than the service under
  test).
- Start each service, then verify it is healthy before running any scenario:
  - HTTP service: poll its health or readiness endpoint until it returns success.
  - Frontend: confirm the dev server responds, or that built assets are served.
  - Upstream simulator or dependency: confirm it accepts connections and, if it
    seeds data, that the service under test has consumed an initial state.
- Record the exact start command and health check for each service in the Setup
  table. If a service fails to come up, stop and report which one and why. Never
  fabricate a partial run over a stack that is not fully up.

---

## State inspection: detect the mechanism, do not assume one

The system's state may live in a database, in memory behind a read API, or in a
snapshot endpoint. Before any discovery or snapshot step, determine which
applies for THIS project from the dev-env doc and the plan:

- Database-backed: use the project's documented local DB connection. Prefer a
  wired database MCP server if one is present in the session tools; otherwise
  fall back to the project's portable CLI (for example a container exec into the
  DB). Verify identity and schema once before relying on it.
- In-memory or single-process: use the read API or a snapshot endpoint the
  service exposes (for example a GET that returns current state). Treat the read
  side as the source of truth for before/after snapshots.
- Never hardcode a connection string, container name, port, or endpoint.
  Discover it and record it in the Setup table.

---

## Critical rules

### Rule 1: Never hardcode entity identifiers

Discover every fixture value from the live system first. Any placeholder like
`<id>` or `<key>` left in the generated file is a violation.

### Rule 2: Never ask the user to set up test data

No "create a record", "delete rows", or "configure X" instructions. Use state
that already exists (seeded during bring-up or already present in the system).

### Rule 3: Identify services, endpoints, and state before generating

Read the implementation plan to determine which services, HTTP endpoints, and
state (tables, in-memory snapshot fields) are involved. If the plan does not make
them clear, ask the user before proceeding. Never assume service-specific paths.

### Rule 4: Always use a unique request identifier per scenario

Append a timestamp to any idempotency key or client-supplied identifier (for
example `key-$(date +%Y%m%d-%H%M%S)`) to avoid collisions with previous runs.

### Rule 5: Mark the file LOCAL ONLY

The generated file opens with a `LOCAL ONLY` warning. Connection details and
payloads carrying real identifiers must never appear in a ticket, wiki page, or
PR body.

### Rule 6: Never modify state as test setup

Do not delete, update, insert, or POST a mutation purely to prepare a scenario.
Find existing state that satisfies the scenario's precondition instead. The only
mutation allowed in a scenario is the action under test itself.

### Rule 7: Snapshot before and after every request

Always capture state before firing a request and compare after. Never rely on
memory of what "should" be there.

### Rule 8: Use the project's documented local auth verbatim, never masked

Read the local auth mechanism from the dev-env doc or env file and write the
literal local value into every generated request. If it is a non-secret,
local-only bypass, write it as-is: a masked placeholder produces a file the user
cannot actually run. If the project has no local auth, state that in the Setup
table. Never invent a credential, and never write a real secret into the file:
if local access genuinely requires a secret, stop and ask the user.

---

## Step 2: Clarify (fill before generating)

| Question | Source |
|---|---|
| Which services must be running for this flow? | dev-env doc + implementation plan |
| How is each service started and health-checked? | dev-env doc / Makefile / task runner / compose |
| Which endpoint(s) trigger the flow under validation? | plan -> handler / route registration |
| What local auth does each service accept? | dev-env doc / env file, or ask |
| How is state inspected (DB, read API, snapshot endpoint)? | dev-env doc + plan |
| Which state changes as a result of the request? | plan File Checklist / What Changes |

If any of these is unclear from the plan, ask the user before generating
scenarios.

---

## Report format

```markdown
## Validation Report -- {slug} -- {date}

| Scenario | Fixture | REQ identifier | Result | Detail |
|---|---|---|---|---|
| S1 | {key identifier} | {id or key} | PASS / FAIL | {brief detail on failure} |
| S2 | ... | ... | PASS / FAIL | |

Overall: PASS / FAIL
Failures: {list any FAIL scenarios with the assertion that did not hold}
```

---

## Output file structure

```markdown
> LOCAL ONLY -- connection details and payloads with real identifiers
> must never appear in a ticket, wiki page, or PR body.

# Manual Test Flow -- {slug} -- {date}

## Setup

### Services

| Service | Start command | Health check | Notes |
|---|---|---|---|
| frontend | {command} | {url or check} | {e.g. dev server / built assets} |
| backend | {command} | {readiness endpoint} | service under test |
| upstream / dependency | {command} | {check} | {e.g. simulator that seeds data} |

### Access

| Field | Value |
|---|---|
| API base URL | {base URL, LOCAL ONLY} |
| Auth | {literal local value, or "none locally"} |
| State inspection | {DB connection / read API / snapshot endpoint, LOCAL ONLY} |

## Scenario matrix

| Scenario | Description | ACs |
|---|---|---|
| S1 | ... | AC-1, AC-2 |

## S1 -- {description}

### Fixture (discovered from the live system)
{query or read used to find the fixture, and the result}

### Request
{curl or HTTP request with real values substituted}

### Expected state
{snapshot query/read + expected output}

### Result
{filled during execution: PASS / FAIL + actual output}

---

## Checklist
- [ ] S1 -- {description}

## Report
{filled during execution}
```

---

## Common mistakes

| Wrong | Correct |
|---|---|
| Hardcode `<id>` or `<key>` in the request | Run fixture discovery first, substitute real values |
| "Create a record as setup" | Find existing state that satisfies the precondition |
| Assume an endpoint from memory | Read the route registration or ask |
| Run scenarios against a half-up stack | Bring up and health-check every service first |
| Single static key across re-runs | Append a timestamp: `key-$(date +%Y%m%d-%H%M%S)` |
| Skip the before-snapshot | Always capture state before firing the request |
| Write connection details into a ticket or PR | The file is LOCAL ONLY: never paste it externally |
| Mask the local auth with asterisks | Write the literal local value, or state "none locally" |
| Assume Postgres / a specific DB | Detect the state-inspection mechanism from dev-env |
