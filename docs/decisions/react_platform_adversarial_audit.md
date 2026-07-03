# Adversarial Audit Report: React Platform UI & Testing Strategy

**Date**: 2026-06-16
**Status**: APPROVED / DOCUMENTED
**Target Configurations**: React platform implementation profile (`.pipeline/profiles/react.md`)

---

## 1. Executive Summary

This report compiles findings and recommendations from five specialized adversarial audit agents. They evaluated the React platform's proposed UI layout, swappable persistence layer, secret management, and testing strategy. 

The audits identified several critical risks, including DOM state destruction during reconfigurable panel reparenting, type and streaming mismatches in the repository layer, high database latency in TDD loops, and deployment drift in security policies. The recommendations have been directly integrated into the React implementation profile.

---

## 2. Audit Findings by Area

### 2.1 UI/UX & Layout Performance (UI/UX Architect)
* **DOM Reparenting Jitter**: Moving split-panes dynamically (swapping top/bottom or vertical/horizontal) destroys the state of the relocated DOM subtree. This wipes out scroll positions, input focus, and reloads iframes.
* **Layout Thrashing & INP**: Running synchronous layout reflow calculations during split-bar drag actions drops frame rates below 30fps.
* **Flash of Unstyled Content (FOUC)**: Setting themes during React hydration causes a bright flash of light-mode UI before local storage configurations load in JS.

### 2.2 Persistence & Type Impedance (Interface & Integration Architect)
* **Interface lowest-common-denominator**: Abstracting Firestore (reactive document streams), gRPC (HTTP/2 binary RPC), and OpenAPI (unary REST) under a single Repository interface strips away the unique capabilities of each. 
* **Type Impedance**: Protobuf v3 lacks primitive `null` support, causing mapping bugs. Numerical float precision limitations in JS can truncate 64-bit backend IDs.
* **Schema Validation Drift**: Defining validation rules across three separate engines (CEL rules, Protobuf schema validators, JSON OpenAPI specs) invites security mismatches.

### 2.3 Testing Speed & Bottlenecks (Database & QA Leads)
* **TDD Latency Penalty**: Forcing all test tiers to run against live databases or emulators adds a 5ms–50ms database round-trip penalty per query. A standard suite of 2,000 unit/widget tests is slowed down from 2 seconds to over 8 minutes.
* **Concurrency Locks**: Spawning parallel CPU threads on Jest/Vitest triggers database write locks and deadlocks on a shared local instance.
* **Tautological Wrapper Testing**: Requiring 85% coverage on simple repository wrappers forces developers to write fragile mock assertions verifying exact SQL query strings, which fails to test database compatibility while increasing maintenance costs.

### 2.4 Security & Configuration Drift (Security & Compliance Officer)
* **Secret Leakage in Git**: Documenting credentials inside version-controlled markdown profiles risks committing secret keys.
* **CORS & CSP Drift**: Relaxing CORS/CSP policies during local development runs the risk of CORS blockages or XSS vulnerabilities when strict policies are deployed to staging/production.
* **IAM Permission Disparity**: Running local emulators with admin credentials masks security issues that arise in production when the app executes under a restricted GCP service account.

---

## 3. Implemented Mitigations

The combined React profile has been updated to enforce the following architectural rules:

### A. Layout & Rendering Mitigations
1. **CSS Variables & Container Queries**: Resizing split-panes dynamically writes inline CSS variables to a grid container, bypassing the React rendering loop until `onResizeEnd`. All nested panels use CSS `@container` queries instead of viewport `@media` queries.
2. **In-Head Theme Script**: Prevent theme flashes by injecting a blocking theme detection script in the HTML `<head>` before rendering any DOM elements.
3. **Ubiquitous Links with Propagation Checks**: Ensure nested button selectors inside clickable list elements call `event.stopPropagation()` to prevent unintended routing navigation.

### B. Persistence Layer & Serialization Mitigations
1. **CQRS Separation**: Implement a clean separation of concerns. Use Firestore for real-time reads/subscriptions, and route writes through gRPC or OpenAPI endpoints where server-side validation can be safely executed.
2. **Layout State Versioning**: Persisted layout configurations in `localStorage` must carry a schema `version` key. A migration runner will reset layout configurations to defaults if schema validation fails, preventing blank screen crashes.

### C. Testing & CI/CD Mitigations
1. **Unit & Widget Mocking**: Unit and widget tests must execute against isolated, thread-safe in-memory stubs (Mock Repositories) for fast, sub-second feedback.
2. **Ephemeral Integration Database**: Database-specific integration tests are run against transient, worker-isolated containers (e.g. Testcontainers) or database transaction boundaries that roll back on `afterEach`.
3. **Exempt Repository Wrappers**: Exclude simple database adapters from the 85% coverage threshold, focusing the coverage requirement strictly on domain logic, math, and validators.

### D. Security & Environment Mitigations
1. **Environment Variables Schema**: Git profiles must document only variable schemas. Secret variables must be loaded from local, git-ignored `.env.local` files and cloud secret managers.
2. **Source-Controlled Security Rules**: Keep Firestore rules and indices inside version control, executing the integration tests directly against the local emulator with security rules enabled.
