# Adversarial Audit & Design Report: Logical UI (LUI) Layer & GPGPU Architecture

**Date**: 2026-06-16
**Status**: APPROVED / DOCUMENTED
**Target Configurations**: Tier 1.5 Logical UI Specifications (`.pipeline/logical-ui/*`), Platform Profiles (`.pipeline/profiles/*`), and Project Constitution (`.pipeline/constitution.md`)

---

## 1. Executive Summary

This report establishes the **Tier 1.5 Logical UI Specification (LUI) Layer** as the platform-agnostic, machine-readable contract for layout structures, design tokens, and components (incorporating classic IBM ILOG JViews TGO industrial state/alarm models and WebGPU/Impeller GPGPU local UI processing architectures).

The audits conducted by five adversarial subagents identified critical risks in duplicating UI requirements across platform-specific profiles, including:
1. **DOM Reparenting Jitter**: State destruction (scroll positions, cursor focus, iframe resets) when React/Flutter rebuilds view trees during layout reconfiguration.
2. **Reflow Storms**: Rendering lag and Input Delay (INP) bottlenecks caused by standard layout resizing events.
3. **The "Round-Tripping" Codegen Deadlock**: Regeneration of UI files overwriting manual styling and performance optimizations.
4. **Reactivity & Event Loops**: Selection state synchronization loops (the Event-Echo deadlock) causing infinite rendering cycles.

To address these vulnerabilities, this document specifies a **UI Adapter Pattern** where optimized, platform-native UI shell containers are written once manually and configured dynamically at runtime using generated JSON schemas. 

Furthermore, to handle a combinatorial explosion of real-time telemetry events and alarms without freezing the UI thread, this report defines a **Zero-Copy GPU-GPGPU UI Architecture** exploiting WebGPU Compute Shaders (React Web) and native Impeller Shaders (Flutter Desktop) to execute layout physics and metric validation directly in VRAM.

---

## 2. Shared UI Architectural Standards

### 2.1. Dynamic State & Status Resolution
To support safety-critical command, control, and observability systems, the UI standardizes the classic 3-pane split layout with a completely dynamic state model. 

The base layout configuration and profiles are completely agnostic of any specific standard (such as ITU-T X.733 or ILOG JViews TGO). All state taxonomies, severity levels, and visual indicators (such as colors and badges) must be resolved dynamically at runtime. The spec engineering pipeline receives these standard definitions as runtime metadata and applies them to the generic UI container without rebuilding or hardcoding specific states.

### 2.2. Standardized Logical UI Components
1. **HierarchyTree (Left Panel)**: Tree-view nested selector (nested levels resolved dynamically from configuration rules) with strict ARIA tree virtualization tags for accessibility.
2. **ResizableSplitter**: Horizontal/vertical split bar with double-click resets and minimum size constraints (150px).
3. **NavigationBreadcrumbs**: Path segment links with sibling drop-down navigation.
4. **PropertyGrid**: Dynamic key-value grid that parses schemas *once* into flat, pre-compiled layout descriptors to avoid render-cycle parsing lag.
5. **TopologyMap (Top Pane)**: Graphical node-link canvas highlighting alarm status outline colors on nodes, supporting pan/zoom, depth/hop constraints, and relation filtering.
6. **DensityTable (Bottom Pane)**: High-density grid containing Object Icon, Name, Type, Family, Alarms, Primary State, and Secondary States.
7. **ContextualPanel**: Slide-out drawer capturing keyboard `Escape` dismiss requests.

---

## 3. Real-Time Event Storm & GPGPU UI Architecture

To prevent main-thread UI starvation under a combinatorial explosion of events, the architecture implements the following rules:

### 3.1. Off-Thread Data Processing
* **React**: gRPC/WebSocket stream connections and binary packet decoding run inside a background **Web Worker**.
* **Flutter**: Sockets and packet parsing run inside a background **Dart Isolate**.
* The main UI thread only receives pre-processed JSON/Dart delta updates.

### 3.2. Micro-Batching & Event Deduplication
* The background worker aggregates incoming events in a memory buffer.
* Events are flushed to the UI in batches at throttled intervals (e.g., every 100ms–200ms). Multiple state changes for the same node within a window are merged, emitting only the final state to eliminate redundant render cycles.

### 3.3. Zero-Copy GPGPU Processing (WebGPU / Impeller Shaders)
For scale-out layouts ($10,000+$ nodes):
* **Compute Shaders**: Graph layout physics (force-directed calculations) are executed in parallel on the GPU using WGSL (WebGPU) or SPIR-V/Metal (Impeller) compute shaders, running $O(N^2)$ calculations in $<1\text{ms}$.
* **VRAM Storage Buffers**: Telemetry values are uploaded directly to VRAM storage buffers. The compute shader evaluates alarm thresholds locally in VRAM, directly updating node color values. The data never travels back to the CPU, eliminating CPU-to-GPU data transmission latency.

---

## 4. UI Adapter Pattern & Linter Enforcement

* **No UI View Codegen**: Generators must not compile raw `.tsx` or Dart view widget files. Instead, code generators output JSON schemas defining columns, validations, and API routes. These are parsed once at startup and injected into pre-optimized React/Flutter shells.
* **Event-Echo Guard**: Property setters must not trigger output event callbacks. Event propagation is restricted exclusively to user-initiated clicks or drag gestures, verified via AST linters.
* **Splitter Optimization**: Dragging resizes updates CSS variables directly in the DOM (React) or isolates painting boundaries via `RepaintBoundary` (Flutter), preventing global subtree rebuilds.
