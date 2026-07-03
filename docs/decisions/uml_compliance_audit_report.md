# UML Compliance Audit Report: Gaps & Missing UML Support

This report consolidates the findings of 5 specialized adversarial subagents deployed to analyze the digital engineering pipeline's UML support, specification templates, and automated linter gates. It enumerates all structural, behavioral, system interaction, traceability, and linter-level defects and provides actionable recommendations.

---

## 1. Executive Summary

The audit reveals a significant gap between the **UML design mandates** defined in the specification worker skills and the **automated verification checks** executed by the linter script (`verify_model_coverage.py`). 

Currently, the linter performs superficial string-presence checks (e.g., verifying that a block starts with ````mermaid classDiagram```` or ````mermaid stateDiagram-v2````) but fails to validate the internal diagram syntax, relationships, or structural parity with the underlying schema. This allows incorrect or placeholder diagrams to pass validation silently, causing quality gaps in generated specs.

---

## 2. Enumerated Gaps and Defects

### A. Structural UML Gaps (Class Diagrams)
* **[GAP-STR-01] Weak Relationship Verification**: The linter script (`verify_model_coverage.py`) accepts any line (`--`) or generic dependency (`-->`) in Class Diagrams, even though `SKILL.md` mandates strict composition (`*--`) or aggregation (`o--`) to represent container hierarchies.
* **[GAP-STR-02] Undetected Isolated Classes**: The linter only triggers an error if a Class Diagram contains *zero* relationships. If a diagram contains a mix of connected classes and completely isolated classes, it passes validation, violating the "no isolated classes" rule.
* **[GAP-STR-03] Choice & Case Stereotype Omission**: When the schema contains a `choice` block, the linter does not verify the presence of the `<<choice>>` stereotype or inheritance (`<|--`) relationships in the diagram.
* **[GAP-STR-04] Text-Only Coverage Loophole**: Node coverage is validated by scanning the markdown prose for the node name in backticks or bold. The linter does not check that the node is actually represented as a class or attribute inside the Mermaid `classDiagram` block.
* **[GAP-STR-05] Missing Constraints Modeling Standard**: There is no standard for representing YANG `must` or `when` clauses in Class Diagrams (e.g., as notes or inline constraints like `{range: 1..10}`).

### B. Behavioral UML Gaps (State Machine & Sequence Diagrams)
* **[GAP-BEH-01] Lack of Feature-Level State Machine Support**: The pipeline only mandates state machine diagrams at the Epic (macro) and Use Case (interaction) levels. Localized stateful lifecycles for individual features (e.g., coordinate status transitions, validation timer countdowns) are completely omitted.
* **[GAP-BEH-02] Superficial Diagram Validation**: The linter only checks for the presence of the `stateDiagram` or `sequenceDiagram` block headers. It does not parse or validate transitions, states, message passing, or lifecycles.
* **[GAP-BEH-03] Inconsistent State Machine Syntax**: Epics are strictly checked for `stateDiagram-v2` syntax, whereas Use Cases accept both `stateDiagram` and `stateDiagram-v2`, causing rendering inconsistencies on platforms like GitHub.
* **[GAP-BEH-04] Sequence Diagram Validation Omissions**: The linter fails to enforce the OOA/OOD rules defined in `spec-user-story-engineering/SKILL.md` (e.g., prohibiting generic `Actor` participant names, mandating validation loops/conditionals using `alt` or `loop`, and requiring typed parameter signatures).
* **[GAP-BEH-05] Hardcoded and Restrictive Templates**: Templates in the skills contain complete, copy-pasteable diagrams with specific names (e.g., `DomainRegistry`, `BusinessLogicService`), leading LLMs to copy placeholders instead of modeling the actual schema behavior.

### C. System Interaction UML Gaps (Use Case Diagrams & Cockburn Format)
* **[GAP-UC-01] Invalid Mermaid Syntax in Templates**:
  * Stereotypes with angle brackets (e.g., `-. <<extend>> .->`) are invalid in Mermaid flowchart syntax without double quotes and fail to render on GitHub.
  * Wrapped state names in square brackets (e.g., `[InitialState]`) are invalid in Mermaid `stateDiagram-v2` and cause parser crashes.
* **[GAP-UC-02] Non-Standard UML Representation**: Use Case diagram templates use standard rectangles (`UC[Title]`) instead of capsule shapes (`UC([Title])`) which represent standard UML ovals.
* **[GAP-UC-03] Use Case Diagram Validation Gap**: The linter does not verify that Use Case diagrams contain a system boundary subgraph, or that nodes representing external actors (`Actor((Name))`) are located outside that boundary.
* **[GAP-UC-04] Brittle Cockburn Flow Step Counter**: Alternate flows are counted using a loose regex (`\b\d+\.\s+\S+`) that counts arbitrary decimals (such as version `1.0` or year `2026.`) as flow steps.
* **[GAP-UC-05] Missing Branching and Guarantee Validation**: The linter does not check that alternate flows explicitly reference the basic flow step they branch from, nor does it check for "Success Guarantee" and "Failure Guarantee" labels under postconditions.
* **[GAP-UC-06] Missing Section 7 Verification**: The linter does not assert the presence of `## 7. Operational Context` in Use Case markdown files.

### D. Traceability & Linkage Gaps
* **[GAP-TR-01] Fragile Title Matching**: `reconcile_backlog.py` prefix-stripping regex fails on bracketed tags (e.g., `[User Story]`) or hyphen separators (e.g., ` - `), causing matching failures against GitHub issues.
* **[GAP-TR-02] Rigid Checkbox Layout Assumption**: The sync script assumes the issue ID (`#IssueID`) immediately follows the checkbox, failing on standard links (e.g., `- [ ] [Title](URL) - #123`).
* **[GAP-TR-03] No Epic Checklist Validation**: The linter does not verify the Epic's `## 2. Requirements & Checklist` section, allowing empty list items, relative paths, or broken links to pass.
* **[GAP-TR-04] User Story Justification Validation Omission**: The linter validates parenthetical justifications for Use Cases but omits them for User Stories, allowing stories to bypass semantic justifications.
* **[GAP-TR-05] Checkbox Mark Case-Sensitivity**: User Story validation accepts only `[x]`, rejecting `[X]`, which is accepted in Use Cases and supported by the reconciler.

### E. Linter & Parser Gaps (verify_model_coverage.py / reconcile_backlog.py)
* **[GAP-LNT-01] Comment-Cleaning Order Bug**: In `parse_yang_file`, the module name is extracted before comments are stripped, leading to matching dummy module declarations in header comments.
* **[GAP-LNT-02] Quote-Wrapped Identifiers Swallowed**: Comment stripping replaces string literals with `""`, erasing quote-wrapped YANG identifiers (e.g. `container "geo-location"`).
* **[GAP-LNT-03] Coverage Leakage**: Linter coverage is verified against a concatenation of all feature files globally, allowing cross-file matching rather than scoping strictly to labeled files.
* **[GAP-LNT-04] Reconciler Frontmatter Parser Bug**: Custom split-on-colon logic erases multiline YAML block descriptions and treats text colons as metadata keys.
* **[GAP-LNT-05] Robustness Failure**: A single stale or missing issue number in any checklist halts the entire reconciler script with `sys.exit(1)`.

---

## 3. Actionable Recommendations

### 1. Upgrade the UML Class Diagram Parser
Modify `verify_model_coverage.py` to parse Mermaid class diagrams structurally:
* Build an adjacency list of relationships and run a connectivity check to assert **zero isolated classes**.
* Verify that composition (`*--`) or aggregation (`o--`) is used for containment hierarchies.
* Assert that case classes inherit from choice classes using `<|--`.

### 2. Implement Diagram-Level Attribute and Schema Parity Verification
* Extract classes and attributes from the Mermaid code blocks.
* Match every YANG schema node to its representation in the class diagram as either a class (containers/lists) or an attribute (leaves/leaf-lists).

### 3. Implement Strict Mermaid Syntax and UML checks in Linter
* **Sequence Diagrams**: Scan for the presence of at least one `alt` or `loop` block, and verify that participant names are descriptive (not generic `Actor`).
* **Use Case Diagrams**: Assert that a `subgraph` (system boundary) exists, and that actors are defined using `Actor((...))` node shapes.
* **State Machines**: Verify that state machine transitions use valid `stateDiagram-v2` syntax.

### 4. Unify Traceability Validation
* Enforce parenthetical justifications `\s+\(([^)]+)\)$` on User Story feature checklists.
* Check Epic checklists for absolute URLs and valid issue mappings.
* Standardize checkbox case insensitivity (`[x]` and `[X]`) across all linter and reconciler checks.

### 5. Fix Linter and Reconciler Code Bugs
* **YANG Parser**: Strip comments/strings *before* running module name regex, and support optional single/double quotes around identifier matches.
* **Reconciler YAML**: Replace the naive line splitter in `reconcile_backlog.py` with a standard YAML library (or robust multi-line parser) to prevent block description erasures.
* **Reconciler Error Handling**: Log warnings instead of crashing with `sys.exit(1)` when a single issue reference is missing.
