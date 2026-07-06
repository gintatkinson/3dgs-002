<!-- Copyright 2026. All rights reserved. -->

---
name: adversarial-code-auditor
description: "Pre-emptive adversarial audit of existing code against four correctness risk pillars: memory safety, resource lifecycle, concurrency correctness, and test integrity. Use when you have a cluster of high-risk defects (UAF, double-free, GPU leaks, async races, brittle tests) and need systematic static-analysis-style review before symptoms manifest. NOT for runtime bugs (use debug-protocol) and NOT for spec-to-code gaps (use spec-implementation-auditor)."
compatibility: "Requires gh CLI and git. Works with any agent runtime that supports subagent dispatch."
metadata:
  title: "Adversarial Code Auditor (Correctness Risk Pillars)"
  category: auditing
  risk: low
  source: custom
  version: "1.2"
---

# Adversarial Code Auditor

## Architecture: Three-Role Separation

This skill enforces a strict separation of concerns. The coordinator (you) NEVER touches issue content. Content flows directly from auditors to the tracker through a dedicated filer subagent.

```
Coordinator (you)
  |
  +-> Auditor Subagent 1  ->  returns issue bodies (READ ONLY)
  +-> Auditor Subagent 2  ->  returns issue bodies (READ ONLY)
  +-> Auditor Subagent N  ->  returns issue bodies (READ ONLY)
  |
  +-> Issue Filer Subagent  ->  writes temp files, runs gh (MODIFIES)
       Receives ALL auditor outputs as raw text.
       Writes each issue body to a temp file verbatim.
       Runs gh issue create --body-file / gh issue comment --body-file.
       Returns list of created issue URLs.
```

| Role | Scope | Tools | Must NOT |
|------|-------|-------|----------|
| **Auditor Subagent** | Audit ONE file, produce 7-section issue bodies | Read, Glob, Grep, Bash (read-only) | Modify files, create issues, run `gh` |
| **Issue Filer Subagent** | Receive auditor outputs, file all issues and comments | Bash (`gh`, `cat`), Write (temp files) | Audit code, summarize, rewrite, edit bodies |
| **Coordinator** | Scope, dispatch, verify URLs | Bash (`gh issue view` for verification only) | Touch issue bodies, run `gh issue create`, audit files |

---

Use this skill to perform pre-emptive adversarial review of source files identified as belonging to high-risk correctness clusters: **memory safety, resource lifecycle, concurrency correctness, and test integrity**. This is a static-review skill — it reasons about code as written, not about runtime behavior. For dynamic debugging of reproducible defects, use `debug-protocol`.

## When to Invoke

- A cluster of related high-risk defects exists (e.g., 5+ open FFI memory bugs in related source files).
- The defects are static/fundamental in nature (UAF, double-free, missing dispose, racy state mutation, non-isolated tests) — not transient runtime symptoms.
- You want to get ahead of the backlog by auditing the correctness of code before symptoms escalate.

## When NOT to Invoke

- The issue is a single, reproducible runtime bug → use `debug-protocol`.
- The issue is a spec-to-code gap (behavior specified but not implemented) → use `spec-implementation-auditor`.
- The issue is a new feature implementation → use `feature-driven-implementation`.

---

## The Four Risk Pillars

Every audit subagent operates through one of these four lenses, weighted by the target cluster:

### 1. Memory Safety (FFI / Native Bridge)
- Double-free, use-after-free, dangling pointers
- Buffer overflows, signed/unsigned wrap
- C++ exception propagation across FFI boundaries
- Native resource finalizer correctness (NativeFinalizer, reference counting)
- Mutex/pointer lifetime in async callbacks

### 2. Resource Lifecycle (GPU / Image / Memory)
- Missing `dispose()` on GPU resources (`ui.Image`, textures, framebuffers)
- Tile/cache eviction correctness under capacity pressure
- Synchronous I/O on UI thread (file reads, heavy parsing)
- GC allocation churn in render/update hot paths

### 3. Concurrency Correctness (Async Races / ViewModel State)
- `ChangeNotifier` disposal-after-notify races
- Unchecked async type-loading races (multiple futures for same key)
- State mutation from `build()` or other synchronous contexts
- Watch/subscription lifecycle against widget disposal

### 4. Test Integrity (Isolation / Reliability)
- FFI/DB-dependent unit tests (should use mocks/stubs)
- `sleep`/`Future.delayed` loops causing flakiness
- Bare `assert()` instead of `expect()` in test functions
- Missing test suite wrappers (`testWidgets` vs raw `test`)
- Duplicated test fakes/stubs across suites

---

## Step-by-Step Workflow

### Step 0 — Pre-flight: Cluster Scoping (Coordinator)

Before dispatching auditors, scope the target cluster:

1. **Query the tracker** for all open issues labeled `bug`:
   ```bash
   gh issue list --limit 1000 --state open --label bug --json number,title,labels,body
   ```
2. **Classify each issue** into one or more of the four risk pillars based on title/body keywords.
3. **Extract file:line references** from each issue body. If an issue body lacks file paths, skip it for the audit — static review needs target files.
4. **Build a per-file hit list**: deduplicate and group by source file. Rank by issue count (most-referenced files first).
5. **Select the target pillar** — if the user specified one, use it. Otherwise, audit the highest-density pillar.

**Gate:** Produce a scoping summary with the target pillar, file hit list, and issue count. Wait for human authorization (`PROCEED`) before continuing to Step 1.

### Step 1 — Per-File Adversarial Audit (Auditor Subagents)

For each source file in the hit list:

**A. Dispatch a fresh isolated Auditor Subagent** with ONLY:
- The file path (subagent reads the file itself)
- The target risk pillar lens (one of the four above)
- The full 8-dimension review framework (below)
- Project conventions (from `.pipeline/constitution.md`, language-specific rules from the active implementation profile)
- A strict instruction: **Read the file. Audit it. Do NOT modify anything. Do NOT create issues. Do NOT run `gh`.** The subagent's ONLY output is the set of complete, ready-to-file issue bodies.
- **Existing review docs** for context (e.g., `docs/reviews/review_cpp_bridge.md`) — if they exist.

**B. Auditor Subagent executes the 8-dimension adversarial review:**

#### 1) Context Understanding
- What is the purpose of this code? (From file path, class names, imports)
- What problem does it solve?
- What are its callers and callees?

#### 2) Correctness Analysis (weighted by risk pillar)
- **Memory Safety pillar weight: HIGH.** Check every raw pointer dereference, every `Pointer.fromFunction`, every `malloc`/`calloc`/`free` pair, every `NativeFinalizer` registration, every FFI string conversion for UAF risk.
- **Resource Lifecycle pillar weight: HIGH.** Check every class for `dispose()`, every `ui.Image` creation for matching disposal, every cache map for eviction-on-write, every `File.readAsStringSync` call.
- **Concurrency pillar weight: HIGH.** Check every `notifyListeners()` for post-disposal risk, every async factory for idempotency, every `build()` override for state mutation.
- **Test Integrity pillar weight: HIGH.** Check every test file for `import 'package:flutter_test/flutter_test.dart'`, absence of `sleep`/`Future.delayed`, presence of `expect()` over `assert()`, correct test wrapper functions.

#### 3) Security Review
- Input validation: Is data crossing FFI/layer boundaries validated?
- Data exposure: Are secrets, tokens, or keys exposed in logs or error messages?
- Injection: Are query strings or native calls constructed from unsanitized input?

#### 4) Performance Considerations
- **Memory Safety:** Are allocations paired with deallocations on all code paths (including error returns)?
- **Resource Lifecycle:** Are cache eviction policies correct under capacity pressure? Is sync I/O on the right thread?
- **Concurrency:** Are locks/guards scoped to minimize contention?

#### 5) Code Quality & Readability
- Are variable and function names intention-revealing?
- Is the code consistent with the project's naming and formatting conventions?
- Are there dead code blocks, commented-out sections, or placeholder stubs?

#### 6) Architecture & Design
- Does the code follow the Clean Architecture pattern from the implementation profile?
- Are repository/adapter boundaries intact (no persistence SDK imports in UI)?
- Are cross-layer dependencies pointing in the correct direction?

#### 7) Testing
- Is there test coverage for the code in this file?
- Do existing tests cover the risk-pillar scenarios (disposal, error paths, FFI boundary conditions)?
- Are tests isolated from real databases, network, and FFI?

#### 8) Documentation
- Are public APIs documented (JSDoc/TSDoc or DartDoc)?
- Are UML traceability tags present (`@realizes UML::ClassName::operationName`)?
- Are complex algorithms explained?

**C. Auditor Subagent output — for each Critical and Important finding, produce a complete, self-contained issue body:**

```
ISSUE_TITLE: [AUDIT] [File name]: [Brief finding description]

ISSUE_BODY:
## 1. Context and References
- **File**: `path/to/file.ext:line-line`
- **Pillar**: [Memory Safety | Resource Lifecycle | Concurrency | Test Integrity]
- **Symptom**: Observable failure caused by this defect

## 2. Root Cause Analysis (5 Whys)
1. **Why ...?** Because ...
2. **Why ...?** Because ...
3. **Why ...?** Because ...
4. **Why ...?** Because ...
5. **Why ...?** Because ...

## 3. Correctness Analysis
[Detailed explanation of WHY the defect is a defect — trace the data flow, identify the invariant being violated, explain the failure mode in concrete terms. Reference the actual source code lines and the 8-dimension review that revealed this finding.]

## 4. UML Diagrams (when applicable)
[Mermaid classDiagram, sequenceDiagram, or stateDiagram-v2 if it clarifies the defect's mechanics.]

## 5. Affected Callers / Downstream Impact
- [Caller 1] — [how it triggers or is affected by this defect]
- [Caller 2] — ...

## 6. Proposed Correction
[Code snippet showing the fix]

## 7. Relationship to Existing Issues
- **Confirms known issue** [#NNN] — if this finding is already tracked
- **Extends** [#NNN] — if this adds new dimensions to a known issue
- **Discovered in audit** — if this is a new finding

## Audit Source
Adversarial [Pillar] Audit — `docs/audits/adversarial-audit-[pillar]-[YYYY-MM-DD].md`
```

Each issue body MUST include all 7 sections. The Output MUST be clearly delimited with `ISSUE_TITLE:` and `ISSUE_BODY:` markers so the Issue Filer can parse them.
- **Severity**: Critical | Important | Suggestion | Nitpick
- **Location**: `path/to/file.dart:123`
- **Issue**: Clear description of the problem
- **Pillar**: [Memory Safety | Resource Lifecycle | Concurrency | Test Integrity]
- **Suggestion**: Specific recommendation for remediation
```

For Suggestions: produce a comment body with the same level of detail, delimited with `COMMENT_FOR_ISSUE: #NNN` and `COMMENT_BODY:`.

**D. Auditor Subagent returns:** All issue bodies and comment bodies for its file, clearly delimited. The subagent does NOT create issues — it only produces the text.

### Step 1.E — Issue Filer Subagent

The coordinator dispatches a SINGLE Issue Filer subagent after ALL auditor subagents have returned.

**The Issue Filer receives:**
1. ALL auditor subagent outputs in full — every `ISSUE_TITLE:` / `ISSUE_BODY:` pair, every `COMMENT_FOR_ISSUE:` / `COMMENT_BODY:` pair
2. The repository name (`gintatkinson/3dgs-002`)
3. A strict instruction: **Write verbatim. Do not summarize. Do not audit code. Do not rewrite.**

**The Issue Filer executes:**

1. For each `ISSUE_TITLE:` / `ISSUE_BODY:` pair:
   ```bash
   cat > /tmp/gh_body_NNN.md << 'ENDOFFILE'
   [paste the ISSUE_BODY exactly as provided — no editing]
   ENDOFFILE
   gh issue create --repo gintatkinson/3dgs-002 --title "[exact ISSUE_TITLE]" --label "bug" --body-file /tmp/gh_body_NNN.md
   ```
   Capture the issue URL from stdout.

2. For each `COMMENT_FOR_ISSUE:` / `COMMENT_BODY:` pair:
   ```bash
   cat > /tmp/gh_comment_NNN.md << 'ENDOFFILE'
   [paste the COMMENT_BODY exactly as provided — no editing]
   ENDOFFILE
   gh issue comment [ISSUE_NUMBER] --repo gintatkinson/3dgs-002 --body-file /tmp/gh_comment_NNN.md
   ```

3. Return the complete list of created issue URLs and comment issue numbers.

**The coordinator MUST NOT insert itself between the auditor and the filer.** The coordinator passes the auditor outputs to the filer without reading, rewriting, or filtering them.

### Step 2 — Cross-Reference Deduplication (Coordinator)

After the Issue Filer returns:

1. **Collect all filed issue URLs** from the Issue Filer subagent output.
2. **Check for duplicates** — same root cause in multiple files (e.g., the same missing `dispose()` pattern across 5 ViewModels). For duplicates, dispatch a coordinator subagent to close the extras and link them to the canonical issue.
3. **Cross-reference across pillars** — a finding may span pillars (e.g., a UAF that also leaks memory). The coordinator subagent adds cross-reference comments.

### Step 3 — Aggregate Risk Report (Coordinator Subagent)

Dispatch a final fresh subagent to produce the aggregate report:

```markdown
# Adversarial Audit Report — [Pillar(s)] — [Date]

## Scope
- Risk pillar(s) audited: [list]
- Source files audited: N
- Open issues in cluster before audit: M
- New issues filed: P

## Findings by Severity
- Critical: X
- Important: Y
- Suggestion: Z

## Findings by Pillar
- Memory Safety: A
- Resource Lifecycle: B
- Concurrency: C
- Test Integrity: D

## Per-File Summary
| File | Critical | Important | Suggestion | Nitpick | New Issues |
|---|---|---|---|---|---|
| `src/ffi/bridge.dart` | 3 | 2 | 0 | 1 | #142, #143, #144 |
| ... | | | | | |

## Cross-Cutting Patterns
- [Pattern 1: description, files affected, canonical issue]
- [Pattern 2: ...]

## Recommended Remediation Priority
1. [Highest-priority finding — block all other work]
2. [...]
```

Save the report to `docs/audits/adversarial-audit-<pillar>-<YYYY-MM-DD>.md`.

### Step 4 — Back-Propagation Decision

After the audit completes:
- If the findings expose a gap in the pipeline tooling or skills (e.g., a class of defect the existing skills cannot catch), this skill itself should be proposed to the upstream `gintatkinson/digital-pipeline-repo`.
- File an upstream issue:
  ```bash
  gh issue create \
    --repo gintatkinson/digital-pipeline-repo \
    --title "Skill Proposal: adversarial-code-auditor (Correctness Risk Pillars)" \
    --body "[Summary of results from pilot audit, signal quality, and rationale for inclusion]" \
    --label "enhancement"
  ```

---

## Persistence Rules
- Each file audit MUST use a fresh subagent — do not reuse or combine contexts.
- Do NOT skip or combine pillars — audit one pillar at a time for signal clarity.
- Every Critical and Important finding MUST be filed as a GitHub issue.
- The coordinator MUST NOT perform file audits itself — scope, dispatch, verify.
- **CONTENT FIREWALL (HARD CONSTRAINT):** The coordinator MUST NOT read, edit, summarize, truncate, compress, or rewrite any auditor subagent's output. Auditor output goes directly to the Issue Filer subagent. A coordinator that touches issue content has violated the three-role architecture.
- The Issue Filer subagent MUST pass auditor output to `gh --body-file` verbatim. No editing allowed.
- The Issue Filer MUST verify after filing that every issue body char count matches the auditor's output.

## Audit Checklist
- [ ] Step 0: Cluster scoped, file hit list built, pillar selected, human authorization received
- [ ] Step 1: All files audited by isolated subagents with full 7-section issue bodies
- [ ] Step 1.E: Issue Filer subagent dispatched with ALL auditor outputs as raw text
- [ ] Step 1.E: All Critical and Important findings filed via `gh issue create --body-file` from auditor output
- [ ] Step 1.E: Issue Filer confirmed each filed issue body matches auditor output (char count + sections)
- [ ] Step 2: Cross-reference deduplication complete
- [ ] Step 3: Aggregate risk report saved to `docs/audits/`
- [ ] Step 4: Back-propagation decision made (upstream proposal)
