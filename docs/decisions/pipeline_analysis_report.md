# Forensic Analysis Report: Specification Content Density Gaps & Root Causes

This report compiles the exhaustive findings from the three specialized sub-agents dispatched to audit the digital pipeline's schema extraction, behavioral modeling, use case engineering, and validation scripts. It identifies the root causes of why the generated specifications (like those in `digipipe-tst14`) are missing mandated content, and details the exact fixes required.

---

## 1. Feature & Schema Extraction Gaps
*Audited by: Pipeline Schema & Feature Extractor Auditor*

### Root Cause 1: Lack of Parent-Child Nesting Mandate in UML Class Diagrams
* **Observation**: In `feat-06-velocity-vector.md` and other features, Class Diagrams show isolated classes (e.g. `velocity` or `GeodeticSystem` in `feat-02`) with no relationships.
* **Why**: The Class Diagram template and guidelines in [schema-specification-engineering/SKILL.md](../../skills/schema-specification-engineering/SKILL.md) only instruct translating the immediate container class. They do not explicitly require showing parent-child composition (e.g. `geo-location *-- velocity`) or cross-container associations (e.g. `velocity`'s dependency on `reference-frame`).
* **Fix**: Update the `SKILL.md` UML Class Diagram guidelines to explicitly mandate that the diagram **must** show the class's nesting relationship to its parent container (up to the root container) and any dependencies on other containers.

### Root Cause 2: Underspecified "Test Data Shape"
* **Observation**: Functional UI Requirements sections lack concrete data representations and only provide simple text lists of types.
* **Why**: While the skill demands a "test data shape," the template does not provide an explicit markdown placeholder or code block example showing a JSON/YAML schema payload.
* **Fix**: Add a concrete JSON example block under `## Functional UI Requirements` to define "Test Data Shape".

### Root Cause 3: Vague Presentation Guidelines
* **Observation**: Presentation requirements are minimal (e.g., "Display coordinates").
* **Why**: The constraint *"without specifying framework-specific components"* is over-generalized by LLMs, leading them to strip out all visual layout details. The skill lacks instructions on detailing platform-independent logical arrangements.
* **Fix**: Revise the prompt guidelines to explicitly require a logical arrangement/layout description (e.g., "Group coordinates together in a 2-column details card; display accuracy bounds below the main coordinates").

---

## 2. Behavioral Story Modeling Gaps
*Audited by: Pipeline Behavioral Story Auditor*

### Root Cause 1: Shallow Sequence Diagrams
* **Observation**: UML Sequence Diagrams in User Stories show generic calls (e.g. `LocationProvider -> LocationRegistry -> VelocityTracker`) and do not model internal calculations, data storage flows, or validation checks.
* **Why**: [spec-user-story-engineering/SKILL.md](../../skills/spec-user-story-engineering/SKILL.md) only mandates "dynamic interaction between the Actor and specific Domain Objects." It does not explicitly demand showing validation gates (e.g. calling a validator class), calculation blocks (e.g. calling a math utility helper), or details like parameters and return types.
* **Fix**: Update the sequence diagram requirements to explicitly show validation checks (calling a validator helper/service), business logic calculations, and parameters/returns.

### Root Cause 2: Missing Stories for Algorithmic & Derived States
* **Observation**: There is no User Story covering the derivation/calculation of speed and heading, even though it is a prominent part of Epic 3.
* **Why**: The story skill only instructs extracting "distinct deployment scenarios" from operational chapters. Mathematical derivations are typically defined in separate technical/algorithmic sections of normative specifications, which the sub-agent skips. There is no behavioral story trigger for derived/calculated values.
* **Fix**: Introduce an **Algorithmic Story Extraction Trigger** to force story generation for derived/calculated values.

---

## 3. Use Case & Traceability Gaps
*Audited by: Pipeline Use Case & Traceability Auditor*

### Root Cause 1: Title-Only and State-Open-Only GitHub Queries in the Skill File
* **Observation**: Use Case `uc-02-derive-speed-and-heading.md` links to User Story `us-04-track-velocity-vector.md` in its realization matrix, but `us-04` contains no logic for speed and heading calculation.
* **Why**:
  1. In [spec-usecase-engineering/SKILL.md](../../skills/spec-usecase-engineering/SKILL.md) (Step 3), the agent is instructed to run `gh issue list --label "user-story" --state "open" --json number,title`. This only fetches the `number` and `title` of User Stories, forcing it to make matches based purely on lexical similarity of titles.
  2. The `--state "open"` filter prevents the agent from finding or linking to any User Stories that have already been closed/completed, even if they are the correct implementations. This leads to artificial matches where the agent maps to whichever open issues happen to be left in the queue.
* **Fix**: 
  - Change the query in Step 3.1 to include both open and closed issues: `gh issue list --label "user-story" --state "all" --json number,title,body`.
  - Explicitly instruct the agent to inspect the content/scenarios of the User Stories to perform semantic mapping rather than name-only matches.
  - Require the agent to add a brief semantic justification to each checkbox link in the matrix (e.g., `- [ ] #41 - [User Story Title](url) - Implements Basic Flow Step 3: Validator Check`).

### Root Cause 2: Insufficient Template Granularity for Alternate/Exception Flows
* **Observation**: Alternate/exception flows in use cases are thin, single-line summaries.
* **Why**: The markdown template in `spec-usecase-engineering/SKILL.md` (Step 4) defines Alternate/Exception flows with only single-line placeholder steps. LLMs rely heavily on the structure and granularity of templates/examples. Providing single-step placeholders acts as an implicit guideline that single-sentence flows are acceptable.
* **Fix**: 
  - Update the template in Step 4 to show detailed, multi-step flows that branch from the Main Success Scenario.
  - Add explicit guidelines in Step 2.5: "Each alternate flow MUST start by identifying the branching point step from the Main Success Scenario, contain at least 2 numbered steps of system/actor interaction, and clearly state the resulting system state or rollback behavior."

### Root Cause 3: Inadequate Verification Linter Gates
* **Observation**: The `verify_model_coverage.py` linter passed successfully despite these severe content gaps.
* **Why**: The linter checks only the *existence* of headers and diagram blocks using simple regular expressions. It does not perform any validation on the main success scenario steps, alternate flows (nor the 2-flow minimum or step count), postconditions, or the realization matrix checkboxes.
* **Fix**:
  - Add structural markdown parsing for use cases to assert the presence of all standard Use Case sections.
  - Validate that Use Cases contain at least two alternate/exception flows, each with a numbered list of at least 2 steps.
  - Verify that the realization matrix contains at least one User Story checkbox and at least one Feature checkbox, using absolute URLs.

### Root Cause 4: Silent Treatment of Hallucinated/Fake Issues in Reconciler
* **Observation**: Hallucinated issue numbers can persist in the codebase.
* **Why**: In `reconcile_backlog.py` (`update_checklist_in_file`), when an issue ID from the matrix is not found in the GitHub registry (e.g. returns `None`), it is silently ignored. It is treated like an open issue, allowing hallucinated issue numbers to persist.
* **Fix**: Modify `update_checklist_in_file` to validate that every issue number found in a checklist actually exists. If it does not, raise an error and exit with a non-zero code.

---

## 4. Proposed Code Diffs & Script Modifications

### 4.1. schema-specification-engineering/SKILL.md Diffs
```diff
--- skills/schema-specification-engineering/SKILL.md
+++ skills/schema-specification-engineering/SKILL.md
@@ -40,11 +40,16 @@
-4. UML Class Diagram: Every Feature specification MUST include a UML Class Diagram (using Mermaid classDiagram) illustrating the domain object class structure, attributes with types, and relationships (aggregations, compositions, inheritances) representing the schema container.
-5. Functional UI Requirements: Every feature spec MUST explicitly include a ## Functional UI Requirements section detailing:
-   - The data that must be stored and retrievable (test data shape, required fields).
-   - The validation logic that must be enforced (constraints, ranges, patterns).
-   - The information that must be visually presented to the user and in what arrangement (e.g., "display all coordinates in a grouped detail view") — without specifying framework-specific components.
+4. UML Class Diagram: Every Feature specification MUST include a UML Class Diagram (using Mermaid classDiagram).
+   - **Hierarchical Composition**: Do NOT show classes in isolation. The diagram MUST illustrate the full container hierarchy from the module root container down to the Feature's target schema nodes, using composition (`*--`) or aggregation (`o--`) relationships.
+   - **Choice/Case Representation**: Model schema `choice` structures as abstract classes or classes with the `<<choice>>` stereotype, and their constituent `case` containers as classes inheriting (`<|--`) from the choice class.
+5. Functional UI Requirements: Every feature spec MUST explicitly include a ## Functional UI Requirements section divided into the following structured sub-sections:
+   - **Test Data Shape (JSON Payload Example)**: A concrete, copy-pasteable JSON payload showing the exact structure of the test data (including nested objects, leaf types, and default values).
+   - **Validation & Constraints**: Exhaustive list of ranges, regex patterns, mandatory fields, and conditions (e.g., "must-after", "if-then").
+   - **Visual Layout & Arrangement**: A detailed, platform-independent description of the visual layout. Instead of vague summaries, detail the visual grouping (e.g., layout sections, information density, visual hierarchy, primary vs secondary rows) without naming framework-specific components.
+   - **Interactive Flow & States**: Detail system states (read-only, edit, empty, loading, error highlighting).
 
@@ -78,6 +83,21 @@
     ## UML Class Diagram
     ```mermaid
     classDiagram
-       class ContainerName {
-           +Type attributeName
-       }
+       class RootContainer {
+           +Type rootAttribute
+       }
+       class NestedContainer {
+           +Type nestedAttribute
+       }
+       class ChoiceContainer {
+           <<choice>>
+       }
+       class CaseContainer {
+           +Type caseAttribute
+       }
+       RootContainer *-- NestedContainer : contains
+       NestedContainer *-- ChoiceContainer : has choice
+       ChoiceContainer <|-- CaseContainer : case
     ```
 
-   ## Functional UI Requirements
-   [UI data/validation/presentation specifications]
+   ## Functional UI Requirements
+   ### 1. Test Data Shape (JSON Payload Example)
+   ```json
+   {
+     "example_key": "example_value"
+   }
+   ```
+
+   ### 2. Validation & Constraints
+   - [Field constraints, ranges, patterns]
+
+   ### 3. Visual Layout & Arrangement
+   - [Detailed grouping, zoning, typographic hierarchy, and information density guidelines]
+
+   ### 4. Interactive Flow & States
+   - [Behavior in read-only vs editable mode, validation error indicators, loading/empty states]
```

### 4.2. spec-user-story-engineering/SKILL.md Diffs
```diff
--- skills/spec-user-story-engineering/SKILL.md
+++ skills/spec-user-story-engineering/SKILL.md
@@ -20,11 +20,16 @@
 You should invoke this skill ONLY after the structural Features have been extracted using the `schema-specification-engineering` skill.
 
-## Step 1: Context Ingestion (Operational Text)
-1. Ingest the target normative specification document.
-2. **IGNORE** the structural schemas (e.g., YANG, OpenAPI, Protobuf) and normative schema definitions.
-3. Target and analyze the following operational chapters:
+## Step 1: Context Ingestion (Operational Text & Schemas)
+1. Ingest the target normative specification document AND the target structural schemas (e.g., YANG, OpenAPI, Protobuf).
+2. **Scan the structural schema definitions** (specifically node descriptions, comments, type restrictions, and validation constraints) to identify:
+   - Any derived, calculated, or computed data fields (e.g., speed and heading derived from a velocity vector).
+   - Any mathematical formulas, equations, unit conversions, or derivations.
+   - Any temporal attributes or state lifecycles.
+3. Target and analyze the following operational chapters of the normative specification:
+   - **Introduction & Applicability**
+   - **Deployment Scenarios**
+   - **Operational Considerations**
+   - **Security Considerations**
+   - **Algorithmic, Calculation, or Derivation clauses**
 
 ## Step 2: Behavioral Modeling (OOA/OOD User Story Extraction)
-For every distinct deployment scenario found, model it as a formal User Story integrated with OOA/OOD principles.
+For every distinct deployment scenario and behavioral trigger found, model it as a formal User Story integrated with OOA/OOD principles.
+
+### Behavioral Extraction Triggers (Mandatory User Stories)
+An agent MUST extract a separate, dedicated User Story if the normative text or structural schema meets any of the following triggers:
+- **Algorithmic/Calculation Trigger**: If the specification or schema defines any mathematical formula, equation, conversion, or derivation (e.g., deriving speed and heading from a velocity vector), it MUST have a dedicated User Story mapping the calculation behavior.
+  - Story format: `As a [System/Actor], I need to calculate [Derived Value] from [Input Values] using [Formula] so that [Outcome].`
+  - BDD scenarios must cover edge cases, rounding, division by zero, and invalid inputs.
+- **Temporal/State Lifecycle Trigger**: If the schema defines temporal attributes (`timestamp`, `valid-until`) or implies state-decay lifecycles, it MUST have a dedicated User Story detailing the transition to expired/stale state and postconditions for stale data access.
+
+### Story Modeling Guidelines
 1. Identify the Actor/Role (the object or entity initiating the action).
 2. Formulate the core scenario using strict BDD syntax mapped to object interactions:
    - `Given` (Precondition object state)
    - `When` (Triggering message or event)
    - `Then` (Postcondition object state)
    - Or standard format: `As an [Actor], I need to [Action/Message] so that [Outcome/State Change].`
 3. Map the story to specific Domain Objects (the structural schema entities affected).
-4. **UML Sequence Diagram:** Every User Story MUST include a **UML Sequence Diagram** (using Mermaid `sequenceDiagram`) illustrating the dynamic interaction between the Actor and specific Domain Objects (e.g. `domainRegistry`, `businessLogicService`), showing method signatures with camelCase parameters (matching the structural schema leaves) and return types/statuses. Naming actor participants as `Actor` is prohibited; use descriptive names (e.g., `clientActor`).
+4. **UML Sequence Diagram:** Every User Story MUST include a detailed **UML Sequence Diagram** (using Mermaid `sequenceDiagram`) illustrating the dynamic interaction between the Actor, Domain Objects, and calculation/validation helpers.
+   - **No Generic Actors**: Naming actor participants as `Actor` is prohibited; use descriptive names (e.g., `clientActor`).
+   - **Typed Method Signatures**: Show method signatures with explicit camelCase parameters, each annotated with its type matching the schema definition (e.g., `operationName(attributeName: DataType)`).
+   - **Typed Return Signatures**: Show explicit return types or object structures returned on the dashed lines (e.g., `ResponseObject(status: StatusType)`).
+   - **Validation Loops**: Model validation loops and conditional logic using Mermaid `alt`/`else` or `opt` blocks, showing both success and validation failure/error execution paths.
+   - **Computation Delegation**: Complex logic, calculations, or validations MUST be delegated to dedicated validator/calculator utility classes (e.g., `BusinessLogicService`, `ValidatorHelper`) and shown explicitly as nested calls (e.g., `domainRegistry ->> businessLogicService: validateBounds(...)`).
 
@@ -75,6 +85,15 @@
 ## UML Sequence Diagram
 ```mermaid
 sequenceDiagram
     autonumber
     actor clientActor as "clientActor : ClientActor"
     participant domainRegistry as "domainRegistry : DomainRegistry"
+    participant businessLogicService as "businessLogicService : BusinessLogicService"
     
-    clientActor->>domainRegistry: operationName(attributeName)
-    Note over domainRegistry: Process operation
-    domainRegistry-->>clientActor: operationResult(success)
+    clientActor->>domainRegistry: operationName(attributeName: DataType)
+    domainRegistry->>businessLogicService: validateBounds(attributeName: DataType)
+    alt [payloadIsValid == true]
+        businessLogicService-->>domainRegistry: ValidationResult(isValid: true)
+        Note over domainRegistry: Store value
+        domainRegistry-->>clientActor: status : Status
+    else [payloadIsValid == false]
+        businessLogicService-->>domainRegistry: ValidationResult(isValid: false, errorReason: String)
+        domainRegistry-->>clientActor: status : Status
+    end
 ```
```

### 4.3. spec-usecase-engineering/SKILL.md Diffs
```diff
--- skills/spec-usecase-engineering/SKILL.md
+++ skills/spec-usecase-engineering/SKILL.md
@@ -29,9 +20,13 @@
-5. Alternate/Exception Flows: Variations in state, error conditions, or alternative paths. You MUST document *at least two* detailed Alternate/Exception flows for every Use Case, covering validation failures, business logic variations, or system/network errors.
+5. Alternate/Exception Flows: Variations in state, error conditions, or alternative paths. You MUST document *at least two* detailed Alternate/Exception flows for every Use Case.
+   - **Branching Point**: Each flow MUST explicitly identify which step of the Main Success Scenario it branches from.
+   - **Detail Level**: Contain at least 2 numbered steps of system/actor interaction.
+   - **Guarantees**: State the resulting state changes, rollback operations, or notifications.
 
@@ -53,2 +59,3 @@
-1. Execute `gh issue list --label "user-story" --state "open" --json number,title` to pull the existing structural inventory.
+1. Execute `gh issue list --label "user-story" --state "all" --json number,title,body` to pull the existing structural inventory.
+2. **Perform Semantic Analysis**: Inspect both titles and content bodies of stories to perform mapping rather than simple title-only matching.
 
@@ -75,3 +86,4 @@
 ## 5. Alternate and Exception Flows
-- **5a. [Condition]:**
-  1. [System/Object] does [Action]
-- **5b. [Exception]:**
-  1. [System/Object] aborts and returns to [State]
+- **5a. [Condition] (Branches from Basic Flow step [X]):**
+  1. [System/Object] does [Action]
+  2. [System/Object] transitions to [State] and returns to step [Y] of the Main Success Scenario.
+- **5b. [Exception] (Branches from Basic Flow step [X]):**
+  1. [System/Object] detects [Error]
+  2. [System/Object] aborts the transaction, rolls back [State], and notifies [Actor].
```

### 4.4. verify_model_coverage.py Updates (UML / Markdown Parsing)
```python
# To be added to verify_uml_diagrams in verify_model_coverage.py
        # Enforce Class Diagram relationships
        if "classDiagram" in content and not re.search(r"(\*--|o--|<\|--|--|-->)", content):
            errors.append(f"Feature {os.path.basename(filepath)} contains a UML Class Diagram with no relationships. Isolated classes are prohibited.")

        # Enforce JSON payload block in Functional UI Requirements
        if not re.search(r"##\s+Functional\s+UI\s+Requirements.*```json", content, re.DOTALL | re.IGNORECASE):
            errors.append(f"Feature {os.path.basename(filepath)} is missing a JSON payload example (```json block) under Functional UI Requirements.")

        # Enforce Use Case structure & alternate flow counts
        if "use-cases" in filepath:
            # Check for Cockburn sections
            required_sections = [
                r"##\s+1\.\s+Actors",
                r"##\s+2\.\s+Preconditions",
                r"##\s+3\.\s+Trigger",
                r"##\s+4\.\s+Main\s+Success\s+Scenario",
                r"##\s+5\.\s+Alternate\s+(?:and|&)\s+Exception\s+Flows",
                r"##\s+6\.\s+Postconditions",
                r"##\s+8\.\s+Realization\s+Matrix"
            ]
            for sec in required_sections:
                if not re.search(sec, content, re.IGNORECASE):
                    errors.append(f"Use Case {os.path.basename(filepath)} is missing mandated section matching pattern '{sec}'.")
            
            # Check for at least 2 alternate flows with numbered steps
            flows = re.findall(r"-\s+\*\*\d[a-z]\..*?(\d+\.\s+\S+.*?)(?=-\s+\*\*\d[a-z]\.|\Z)", content, re.DOTALL)
            if len(flows) < 2:
                errors.append(f"Use Case {os.path.basename(filepath)} must contain at least 2 detailed Alternate/Exception flows.")
            else:
                for idx, flow in enumerate(flows):
                    steps = re.findall(r"\b\d+\.\s+\S+", flow)
                    if len(steps) < 2:
                        errors.append(f"Use Case {os.path.basename(filepath)} alternate flow {idx+1} is too thin (must contain at least 2 numbered steps).")
```

### 4.5. reconcile_backlog.py Hallucination Gate
```python
# To be added to reconcile_backlog.py inside update_checklist_in_file
        if dep_issue is None:
            print(f"Error: Invalid/hallucinated dependency reference #{dep_num} in {os.path.basename(filepath)}")
            sys.exit(1)
```
