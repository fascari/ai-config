# Harness Architecture

## Enforcement Flow

```mermaid
flowchart TD
    ORC[orchestrating-tasks\norchestrator]

    ORC --> VLI

    subgraph VLI[validate-loop — isolated context, Balanced model]
        direction TB
        subgraph IMPL[go-implementer — isolated context per cycle]
            CODE[write code] --> LINT[linter + style gate]
        end

        LINT --> HGI

        subgraph HGI[harness-gate — isolated context, Fast model]
            HI[harness-validate.sh\n--phase=implementation]
            HI --> DI[Deterministic + Semantic]
            DI --> RI{All pass?}
        end

        RI -- yes --> PASSI[LOOP PASS\nphase: implementation]
        RI -- no --> CHK1{incorrigible\nor max iter?}
        CHK1 -- no --> FIX1[scoped fix prompt\nfiles in violation only]
        FIX1 --> IMPL
        CHK1 -- yes --> FAILI[LOOP FAIL\nescalate: true]
    end

    PASSI --> ORC2[orchestrator\nreceives ~100 tokens]
    FAILI --> ORC2

    ORC2 -- LOOP PASS --> VLT

    subgraph VLT[validate-loop — isolated context, Balanced model]
        direction TB
        PG[require-receipts.sh\nimplementation gate] --> PGR{valid?}
        PGR -- stale/missing --> FAILPRE[LOOP FAIL\nprerequisite gate failed]
        PGR -- valid --> BL[load baseline-report]
        BL --> TESTI

        subgraph TESTI[go-tester — isolated context per cycle]
            WRITE[write + run tests]
        end

        WRITE --> HGT

        subgraph HGT[harness-gate — isolated context, Fast model]
            HT[harness-validate.sh\n--phase=testing]
            HT --> DT[Deterministic + Semantic]
            DT --> RT{All pass?}
        end

        RT -- yes --> PASST[LOOP PASS\nphase: testing]
        RT -- no --> CHK2{incorrigible\nor max iter?\nproduction file touched?}
        CHK2 -- no --> FIX2[scoped fix prompt\ntest files only]
        FIX2 --> TESTI
        CHK2 -- yes --> FAILT[LOOP FAIL\nescalate: true]
    end

    PASST --> ORC3[orchestrator\nreceives ~100 tokens]
    FAILT --> ORC3
    FAILPRE --> ORC3

    ORC3 -- both LOOP PASS --> TDJ[test-design-judge\ncross-vendor, Balanced]
    TDJ -- APPROVED --> OJ[output-judge\ncross-vendor, Deep]
    TDJ -- BLOCKED --> REPAIR[1 repair cycle\nre-judge]
    REPAIR -- still BLOCKED --> ORC3

    OJ -- PASS --> CC[committing-changes]
    CC --> GC[require-receipts.sh\nimplementation testing]
    GC -- any stale/missing --> FAIL4[exit 1\nblock commit]
    GC -- both valid --> COMMIT[git commit\nallowed]
```

> **Key design principle**: `harness-gate` (Fast model, isolated) is dispatched by `validate-loop` at each iteration cycle, not by the orchestrator directly. The `validate-loop` agent (Balanced model, isolated) owns the repair loop for one phase — it runs code-agent + harness-gate cycles, detects incorrigible violations, and returns only a compact `LOOP PASS` or `LOOP FAIL` block (~100 tokens) to the orchestrator. All violation details, fix prompts, and repair output are discarded when validate-loop exits. The orchestrator never calls `harness-validate.sh` directly and never sees intermediate repair state.

## Component Map

```mermaid
graph LR
    subgraph Entry Points
        HV[harness-validate.sh]
        RR[require-receipts.sh]
        HR[harness-report.sh]
    end

    subgraph Phases
        PI[phases/implementation.sh]
        PT[phases/testing.sh]
    end

    subgraph Lib
        AP[lib/active-plan.sh]
        PR2[lib/plan-root.sh]
        SC[lib/scope.sh]
        LJ[lib/llm-judge.sh]
        RC[lib/receipt.sh]
        IM[lib/instructions-map.yaml]
    end

    subgraph Deterministic
        ML[deterministic/lint.sh]
        MU[deterministic/unit.sh]
        MI[deterministic/integration.sh]
        GV[deterministic/vet.sh]
        GF[deterministic/fmt.sh]
    end

    HV --> PI
    HV --> PT
    PI --> SC
    PT --> SC
    PI --> ML
    PI --> GV
    PI --> GF
    PT --> MU
    PT --> MI
    PI --> LJ
    PT --> LJ
    LJ --> IM
    PI --> RC
    PT --> RC
    RC --> AP
    AP --> PR2
    RR --> AP
    HR --> AP
```

## Receipt Schema

```json
{
  "phase": "implementation",
  "head_sha": "abc123...",
  "diff_hash": "sha256 of git diff HEAD",
  "scope": ["path/to/changed/package/"],
  "timestamp": "2026-05-26T14:00:00Z",
  "deterministic": [
    {"check": "lint",   "result": "pass"},
    {"check": "vet",    "result": "pass"},
    {"check": "fmt",    "result": "pass"}
  ],
  "semantic": [
    {"instruction": "go-style.md",   "result": "pass", "violations": []},
    {"instruction": "writing-modern-go/SKILL.md",  "result": "pass", "violations": []},
    {"instruction": "error-handling.md", "result": "fail",
     "violations": [{"file": "foo.go", "line": 42, "rule": "...", "severity": "high"}]}
  ],
  "overall": "fail"
}
```
