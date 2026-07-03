# Consolidated Design Report: High-Performance Multi-Platform Logical UI & GPGPU Architecture

**Date**: 2026-06-16  
**Status**: APPROVED / MANDATED  
**Applicable Workspace**: `digital-pipeline-repo`  
**Target Platform Environments**: React Web (Vite) & Flutter Desktop/Web  

---

## 1. Executive Summary

This report establishes the **Tier 1.5 Logical UI Specification (LUI) Layer** as the platform-agnostic, machine-readable contract for layout structures, design tokens, and components across all UI distributions (React and Flutter). 

Fundamentally, this architecture is designed to support time-, space-, and motion-sensitive real-time safety-critical command, control, observability, and situational awareness systems. These systems span applications in energy grids, nuclear power generation, air traffic control, battlefield command, network SDN controllers, and AI infrastructure.

Taking inspiration from legacy systems like **IBM ILOG JViews TGO**—which pioneered robust, real-time industrial UI state models but accumulated technical debt due to heavy client footprints and proprietary rendering loops—this modern architecture cuts out legacy debt by utilizing:
1. **The UI Adapter Pattern**: Platform-native UI shells configured dynamically at runtime via JSON schemas, preventing code generation deadlocks.
2. **Off-Thread Data Pipelines**: Background workers (React Web Workers) and isolates (Dart Isolates) handling gRPC/WebSocket stream processing.
3. **Zero-Copy GPGPU Acceleration**: Performing graph layout physics and alarm threshold validation directly in VRAM via WebGPU Compute Shaders (React) and Impeller Custom Shaders (Flutter).
4. **The Event-Echo Guard**: AST-enforced event propagation constraints preventing rendering loops in bidirectional selection trees.

---

## 2. Tier 1.5 Logical UI Specification (LUI) Layer

The Logical UI Layer resides in the `.pipeline/logical-ui/` directory and acts as the single source of truth for design tokens, component behaviors, and declarations.

### 2.1. Standard-Agnostic Design Tokens
Design tokens specified in `design-tokens.json` declare the platform-independent brand, surface, background, typography, and spacing visual variables. They do not pre-code any specific standard or alarm severities (such as ITU-T X.733):

* **Primary Accent Color**: `#1a73e8` (Google Blue / Brand Accent)
* **Standard Agnosticism**: All domain-specific alarms, states, and their associated severity colors are treated as dynamic runtime metadata. The spec engineering pipeline receives the standard definition and its color mappings as part of the dynamic runtime payload.
* **Typography**: Outlined scale using the `Outfit` or `Roboto` font families configured for high-density visualization.

### 2.2. Standardized Logical UI Components
We define exactly seven core platform-agnostic components:
1. **HierarchyTree**: Virtualized tree nested selector supporting focus navigation (`ArrowUp`/`ArrowDown`), folder expansion/collapse, and strict ARIA roles.
2. **ResizableSplitter**: High-performance multi-pane splitter enforcing minimum dimensions (150px), snap-to-edge, and reconfigurable positions without state loss.
3. **NavigationBreadcrumbs**: Responsive breadcrumb path collapsing middle segments into ellipses (`...`) when widths are exceeded.
4. **PropertyGrid**: A high-speed key-value display that compiles dynamic JSON schemas into flat, pre-compiled layout descriptors once.
5. **TopologyMap**: A 3D/4D spatial-temporal canvas (WebGL/WebGPU/Impeller) rendering objects in 3D coordinate space, tracking dynamic trajectories, displaying volumetric bounds, and hosting timeline playback controls.
6. **DensityTable**: A high-density virtualized table dynamically displaying all configured and allowed attributes, properties, and child elements for the associated managed object or element based on its data schema. Supports integration within a bottom-docked `TabbedContainer` hosting multiple tabbed lists (e.g. Elements, Alarms, Events) for the active selected object.
7. **ContextualPanel**: Slide-out drawer capturing key events like `Escape` for dismissal.

### 2.3. Declarative Layout Schema
Layout configurations are specified in `logical-layout.json` using dynamic layout configuration tokens that reference abstract paths and target states (e.g., `selected_managed_object`), separating layout declaration from platform runtime code.

---

## 3. Platform Implementation Profiles

To prevent platform divergence and ensure that the shared LUI specs are correctly implemented, specific developer profiles are enforced.

### 3.1. React Web Profile (`.pipeline/profiles/react.md`)
* **Stack**: React 18, Vite, TypeScript 5.x (Strict mode).
* **Decoupling**: Direct SDK imports (Firebase, gRPC) are forbidden in components. They must depend on interfaces defined under `src/core/persistence/repository.interface.ts`.
* **Splitter Optimization**: Drag resizes must modify CSS variables on the grid container directly in the DOM, bypassing the React rendering loop until drag completion (`onResizeEnd`) to ensure 60fps interaction.
* **Telemetry Pipeline**: Binary packet parsing (Protobuf/gRPC) runs in a background **Web Worker**. Large topology maps utilize **WebGPU compute shaders** for force-directed layout calculations.
* **Hydration Flash (FOUC)**: A blocking theme script is injected in the HTML `<head>` to prevent flash-of-unstyled-content during dark/light mode load.

### 3.2. Flutter Desktop/Web Profile (`.pipeline/profiles/flutter.md`)
* **Stack**: Flutter SDK 3.x, Dart 3.x.
* **Decoupling**: Widgets must not directly call Firestore/gRPC; they must use provider-injected repository classes under `lib/core/persistence/`.
* **Splitter Optimization**: Splitter operations isolate rendering boundaries using `RepaintBoundary` widgets on the `TopologyMap` and `DensityTable` to prevent rebuilding unchanged widget trees.
* **Telemetry Pipeline**: gRPC stream listening and decoding run on a background **Dart Isolate**. The main UI isolate receives only pre-parsed model objects. Graph physics are computed via **Impeller custom shaders** (Vulkan/Metal/WebGL2).
* **Engine Bootstrap Splash**: Native splash screens match theme configurations in `index.html` to avoid a loading flash before CanvasKit initializes.

---

## 4. Real-Time Event Storm & GPGPU UI Architecture

When scale-out systems reach $10,000+$ managed elements, a combinatorial explosion of real-time alarms and telemetry updates can easily cause UI thread starvation (freezing the screen and introducing significant Input Delay). To prevent this, we enforce a strict off-thread and GPU-accelerated pipeline.

```mermaid
flowchart TD
    subgraph "Background Thread (Web Worker / Dart Isolate)"
        A[gRPC/WebSocket Stream] -->|Raw Binary Packets| B[Packet Parser & JSON Decoder]
        B -->|Unfiltered Events| C[Micro-Batching Buffer]
        C -->|Aggregate & Deduplicate 100ms| D[Throttled Event Batcher]
    end

    subgraph "GPU VRAM (WebGPU / Impeller Compute)"
        E[VRAM Storage Buffers] -->|Parallel Force-Directed Physics| F[Layout Compute Shader]
        E -->|Threshold Evaluation| G[Alarm Threshold Shader]
        G -->|Update Outlines/States| H[Renderer]
    end

    D -->|Pre-Processed Delta Updates| I[Main UI Thread]
    I -->|Direct VRAM Upload| E
    H -->|60fps Screen Draw| J[Display]
```

### 4.1. Micro-Batching & Event Deduplication
1. **Off-Thread Parse**: All network telemetry streams (WS/gRPC) are received and parsed off the UI thread (Web Worker / Dart Isolate).
2. **Buffer Window (100ms)**: Incoming packets are accumulated in a background buffer.
3. **Coalesce Updates**: If the same resource receives multiple status/alarm updates within the 100ms window, the events are coalesced (e.g., if alarm status changes from Cleared $\rightarrow$ Warning $\rightarrow$ Critical, only the final state `Critical` is sent).
4. **Batch Transmission**: Pre-processed delta updates are sent as a single message batch to the main UI thread.

### 4.2. Zero-Copy GPGPU (WebGPU & Impeller)
Instead of copying graph node coordinates back and forth between the CPU and GPU memory during physics layout calculations:
1. **GPU-Bound Physics**: Node arrays and edge links are stored in GPU **Storage Buffers**. Force-directed physics algorithms are executed as GPU **Compute Shaders** (WGSL/Metal), bypassing the CPU entirely.
2. **Direct Thresholding**: Telemetry values are uploaded directly to GPU memory buffers. Compute shaders evaluate status thresholds (e.g., evaluating if a metric exceeds the critical limit) directly in VRAM.
3. **Direct Render Pipe**: The vertex shaders read directly from the compute shader's output storage buffers to draw nodes and links. Node states and coordinates never travel back to the CPU, reducing bus traffic and keeping the main UI thread fully responsive.

---

## 5. UI Adapter Pattern & Event-Echo Guard

### 5.1. UI Adapter Pattern
To solve the **"Round-Tripping" Codegen Deadlock** (where compiler scripts regenerate UI code, overwriting custom performance overrides, inline comments, and local styling):
* **No View Code Generation**: Code generators must never output `.tsx` or `.dart` UI files.
* **Declarative Routing & Configuration**: Generators parse specifications to produce dynamic JSON files describing layout nesting, column models, API bindings, and routing tables.
* **Hand-Optimized Shells**: Hand-written and highly-optimized native React/Flutter view components parse these JSON files at runtime to mount tree items, splitter positions, and tables. 

### 5.2. Event-Echo Guard
When components display bidirectional selections (e.g., clicking a node in the **TopologyMap** highlights the item in the **HierarchyTree**; selecting a node in the **HierarchyTree** shifts the map focus), property updates can echo back and forth in an infinite rendering loop.

To prevent this:
1. **Separate Event Triggers**: Component setters/methods that change state programmatically (e.g., `setSelection(id)`) must *only* update internal state and repaint. They must never trigger output callbacks like `onSelectionChanged`.
2. **User Interaction Restriction**: Output event callbacks (e.g., `onNodeSelect`) are fired *exclusively* in response to user-initiated gestures (clicks, taps, keyboard presses).
3. **Linter Enforcement**: Codebases must verify via AST linters that programmatically-triggered setters do not call dispatch events, and that custom interaction handlers explicitly include `event.stopPropagation()` (or platform equivalents).

---

## 6. Adversarial Critiques & Mitigation Strategies

Prior to design finalization, five adversarial agents audited this architecture. Below are the consolidated risks identified and their corresponding mitigations:

| Area | Adversarial Critique | Approved Mitigation |
| :--- | :--- | :--- |
| **State Jitter** | Changing layouts or swapping splitter panes causes state destruction (scroll position resets, iframe reload, keyboard focus loss). | **DOM Isolation**: React views must use static absolute positioning wrappers with wrapper-level CSS transitions rather than structural unmounting. Flutter must utilize persistent `GlobalKey` references. |
| **Reflow Storms** | Splitter resize drag operations trigger continuous reflows down the layout tree, starving input response. | **Paint Isolation**: Drag actions must only update local CSS variables on the root grid wrapper. Sub-components must utilize CSS `contain: layout paint` (Web) or `RepaintBoundary` (Flutter) to avoid layout recalculation of children until resize completes. |
| **API Drift** | Swapping adapters between Firebase, gRPC, and OpenAPI exposes data-model mapping and parsing differences. | **Adapter Repository Pattern**: Enforced strict interface declarations at `repository.interface.ts`. Components consume abstract interfaces, and adapter classes are isolated with zero cross-leakage. |
| **State Contamination** | Running tests directly against shared emulators causes parallel execution lockups and state contamination. | **Clean-Slate Emulators**: CI/CD runs tests sequentially or spawns isolated emulator containers per test worker thread, using clear-database scripts between runs. |
| **Codegen Divergence** | Schema changes could lead to diverging JSON configuration schemas, breaking client runtime code. | **Schema Validator**: Build pipelines run a pre-build JSON Schema linter asserting that generated schemas match the metamodel schema specified in `.pipeline/logical-ui/*`. |

---

## 7. Verification and Linter Mandates

To ensure developers and code-generation tools adhere to these architectural standards, the build pipeline enforces automated checks:

1. **AST Checkers**:
   - Assert that no component files containing raw UI elements are created dynamically under the source directories (`src/` or `lib/`) by generators.
   - Parse event callbacks in React/Flutter views to ensure `event.stopPropagation()` is invoked on nested handlers.
2. **Test-Driven Development**:
   - The TDD mandate requires writing failing unit/widget tests first.
   - All client code must run tests against local emulators/containers to ensure full coverage of database and API interaction paths.
   - Statement coverage must meet the 85% threshold for logic/validators/calculators.

---

## 8. Domain Extensibility and Design-Time Schema Compilation

The declarative layout schema is structured to scale and support domain-specific variants at design time. This model is clear, workable, and eliminates the historical technical debt of legacy systems:

### 8.1. Separation of Concerns (Core vs. Domain)
* **The Core UI Engine**: Platform-native UI shells (React, Flutter) only understand generic logical UI components (`SidebarLayout`, `SplitWorkspace`, `TableView`, `TopologyMap`, `PropertyGrid`).
* **Design-Time Domain Bindings**: At design time, layout declarations bind components to domain-specific schemas using dynamic configuration tokens:
  - **Telecom / Network Domain**: Binds to dynamic schema paths (e.g., matching the network topology namespace configuration).
  - **Energy / Power Grid Domain**: Binds to dynamic schema keys (e.g., matching the power system resource configuration).
  - **Logistics / Marine Ports**: Binds to dynamic container states and spatial coordinates.

### 8.2. Design-Time Compilation & Validation
To guarantee that declarative layouts are valid and error-free before compiling the production bundle:
1. **Schema Linter**: During build pipelines, a linter script parses `logical-layout.json` and asserts that all `data_source` paths map directly to allowed nodes in the compiled schema directory (e.g., validating the YANG schemas or OpenAPI specifications).
2. **Type Safety**: Design-time compilation generates typed bindings for the React and Flutter runtimes. If a property or attribute requested in a layout does not exist in the domain-specific model, compilation fails.

### 8.3. Future Component Extensions
When a new domain requirement demands a new visualization component (e.g., a time-series line chart or timeline grid):
1. The new component type is registered in the LUI metamodel spec (`logical-components.md` and the JSON Schema).
2. Native implementations of the component are coded once inside the React and Flutter engines.
3. Design-time declarations can immediately begin utilizing the new component, ensuring absolute decoupling between representation and layout configuration.

---

## 9. Spatial-Temporal (4D) Logical Grouping & Visualization

> [!NOTE]
> For a detailed mathematical and technical dive into coordinate translations, temporal contexts, TLE/SGP4 propagation, and GPU compute pipelines, read the full [Spatial-Temporal (4D) UI Analysis](decisions/spatial_temporal_4d_ui_analysis.md).

Real-time safety-critical control environments (subsea, air traffic control, satellite telemetry, and extraterrestrial exploration) manage elements that are not static or structured strictly in a parent-child BOM hierarchy. Instead, objects are dynamically moving in 3D coordinate space over time.

To support these movements and trajectories, the framework implements a 4D Spatial-Temporal logical grouping architecture.

### 9.1. Defining Space-Time (4D) Groupings
* **Non-Structural Aggregation**: Elements can be grouped dynamically based on 3D boundary containers (e.g., atmospheric sectors, orbital inclinations, deep-sea bounding boxes) and time windows $[t_{start}, t_{end}]$.
* **4D Query Engine**: Rather than loading static trees, the UI query engine issues spatio-temporal range requests (e.g., "return all rovers currently within a 10km radius of the Mars Olympus Base station at time $t$"). The data adapter parses these query boundaries, returning the filtered list of objects and their trajectory vectors.

### 9.2. UI Control & Navigation (Timeline Scrubber & 3D Canvas)
1. **Interactive Timeline Playback**: The UI shell provides a global simulation/playback controller (play, pause, fast-forward, timeline slider). Modifying the slider updates a global `simulation_time` context variable.
2. **Dynamic Trajectory Projection**: The `TopographicalView` rendering engine maps latitude, longitude, altitude, and timestamps to draw 3D coordinate paths and predict future conjunctions/positions based on motion vectors.
3. **Synchronization across Splits**: Selecting a point along an object's trajectory updates the active timeline, updating the dynamic attributes in the `PropertyGrid` and `TableView` to show the telemetry states corresponding to that specific space-time coordinate.

### 9.3. GPGPU Trajectory Computation
Calculating orbital intersections or collision routes for thousands of moving objects in real-time is computationally intensive. 
To preserve UI responsiveness:
* **Background Prediction**: Trajectory extrapolations run in Web Workers (React) or background Isolates (Flutter).
* **VRAM Coordinate Mapping**: Motion equations (Keplerian elements, spline interpolations) are calculated in parallel via GPU compute shaders, updating the vertex positions in VRAM directly to redraw paths at 60fps without CPU pipeline stalls.

---
