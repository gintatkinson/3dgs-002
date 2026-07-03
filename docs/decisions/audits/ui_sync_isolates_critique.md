# Code Audit: UI Thread Synchronization, Time-State Machines, and Memory-Sharing Models

**Audited Documents:**
* `docs/decisions/spatial_temporal_4d_ui_proposal.md`
* `docs/decisions/spatial_temporal_4d_ui_analysis.md`

**Target Platform Runtimes:** React Web (WebGPU/WGSL) & Flutter Desktop (Impeller/Metal/Vulkan/Dart FFI)

---

## Executive Summary

This audit evaluates the architectural decisions regarding the 4D Spatial-Temporal Viewer. While the use of Double-Single (DS) split-precision emulation, floating origins, and GPU-driven rendering resolves core visual precision and CPU-GPU bandwidth issues, the current proposals exhibit **critical race conditions, control loop instabilities, memory leaks, and serialization bottlenecks** across the UI thread synchronization, time-state machines, and memory-sharing boundaries. 

The most severe findings include:
1. **Time-Reversal and Saturation Vulnerabilities** in the PID clock-rate smoothing controller.
2. **Memory Leaks and Use-After-Free (UAF) Vulnerabilities** in the Dart FFI C-heap pointer lifecycle.
3. **Buffer Neutering Starvation** in the double-buffered React Web Worker model when frame drops occur.
4. **Data Tearing and Lacking Fences** during cross-thread shared memory access.
5. **WGSL-to-CPU Structure Alignment Mismatches** resulting in GPU validation failures.

---

## 1. Playback Synchronization & Time-State Machine Vulnerabilities

### 1.1. PID Clock-Rate Smoothing Loop Instability Math & Time-Reversal Hazard

The proposal suggests driving the client-side playhead $t_{play}$ via a PID controller that dynamically adjusts the playback clock speed factor $r(t) = 1.0 \pm 0.05$ to match a target delay offset:
$$t_{target}(t) = t_{stream\_max}(t) - \Delta t_{buffer}$$

Let the error function be:
$$e(t) = t_{target}(t) - t_{play}(t)$$
And the playback rate update equation:
$$r(t) = 1.0 + K_p e(t) + K_i \int_{0}^{t} e(\tau) d\tau + K_d \frac{de(t)}{dt}$$
Where $t_{play}(t) = \int_{0}^{t} r(\tau) d\tau + t_{play}(0)$.

#### The Flaws:
1. **Time-Reversal Risk**: If $e(t)$ becomes highly negative (e.g., during a network freeze where $t_{stream\_max}$ stops advancing, but $t_{play}$ continues forward), the proportional ($K_p e(t)$) and integral ($K_i \int e(\tau) d\tau$) terms will output negative values. If not clamped strictly to a positive lower bound (e.g., $r(t) \ge 0.0$), the rate $r(t)$ will drop below zero, forcing $t_{play}$ to run **backwards**. 
2. **Integrator Windup & Saturation Oscillations**: Clamping $r(t) \in [0.95, 1.05]$ solves time-reversal but introduces non-linear windup. During a network freeze, the controller saturates at $r(t) = 0.95$. The integral term will accumulate a massive negative value:
   $$\lim_{t \to t_{freeze}} \int_{0}^{t} e(\tau) d\tau = -\infty$$
   When the stream resumes and a burst of queued packets arrives, $t_{stream\_max}$ and $t_{target}$ jump forward. The error $e(t)$ becomes positive, but the saturated negative integral term prevents $r(t)$ from increasing immediately. Playback remains stuck at $0.95 \times$ speed for several frames (or seconds) until the error integrates enough to cancel the windup, followed by a violent snap to $1.05 \times$. This creates extreme visual judder.
3. **Derivative Kick from Out-of-Order Packets**: A late-arriving packet with a high timestamp causes a step-discontinuity in $t_{stream\_max}(t)$. The derivative term $K_d \frac{de(t)}{dt}$ evaluates to a Dirac delta impulse $\delta(t)$, causing the playback rate $r(t)$ to instantly saturate at $1.05$, causing a sudden frame jump.

#### Remediations:
* **Switch from PID to a Phase-Locked Loop (PLL) with Low-Pass Filtering**: Drive $t_{play}$ using a second-order Phase-Locked Loop (PLL) where the clock rate is smoothed via a Low-Pass Filter (LPF) on the error, rather than raw derivative terms.
* **Clamping and Anti-Windup (Clamping Method)**: Enforce a strict clamp on $r(t) \in [0.90, 1.10]$ and freeze integration when the rate saturates:
  $$\text{If } r(t) \ge r_{max} \text{ and } e(t) > 0, \quad \frac{d}{dt} \text{Int}(t) = 0$$
  $$\text{If } r(t) \le r_{min} \text{ and } e(t) < 0, \quad \frac{d}{dt} \text{Int}(t) = 0$$

---

### 1.2. Inter-Thread Drift & Temporal Boundary Race Conditions

The proposal relies on `isTemporalBoundary = true` to flush velocity registers and prevent acceleration spikes in spline engines during transitions (e.g., historical scrub to live).

#### The Flaws:
1. **Asynchronous Frame Mismatch**: Web Workers and the Main Thread operate on separate event loops. If the UI dispatches a state transition and sets `isTemporalBoundary = true`, there is a non-zero propagation delay before the Worker processes the message. During this window, the main thread may render 1-2 frames using the *old* spline coefficients with the *new* clock offset, resulting in coordinate spikes (e.g., rendering the aircraft at coordinate $(0,0,0)$ or light-years away for a single frame).
2. **State Machine Deadlocks**: If the client switches from `PlaybackMode` to `LiveMode`, the local rendering clock is abruptly shifted from $t_{historical}$ to $t_{live}$. The proposal does not specify how the WebSocket client resumes telemetry streaming. If the buffer is not cleared, the UI will attempt to replay the accumulated queue of live telemetry packets that were ignored during playback, causing an "event storm" that freezes the UI thread.

#### Remediations:
* **Generational State Tokens**: Pair all time state updates with a monotonically increasing `StateEpoch` (integer). The spline evaluation shader and the worker must discard any keyframes or calculations whose `StateEpoch` does not match the active frame epoch.
* **Epoch-Based Queue Flush**: When transitioning to `LiveMode`, discard all queues in the worker and send a clear signal to the WebSocket client to re-request the current state before accepting new delta frames.

---

## 2. Jitter Buffer & Micro-Batching Bottlenecks

### 2.1. Telemetry Batching vs. Queue Starvation

To optimize CPU performance, network payloads are micro-batched (e.g., aggregated every 100ms before dispatching to workers).

#### The Flaws:
1. **Starvation Cycle**: If the jitter buffer offset $\Delta t_{buffer}$ is less than the batching interval $\Delta t_{batch}$ plus transmission latency (i.e., $\Delta t_{buffer} < 100\text{ms} + \text{network jitter}$), the playhead will routinely catch up to the latest packet. The queue starves, halting spline playback. When the next batch arrives, the playback jumps forward, causing stutter.
2. **Buffer Bloat**: If $\Delta t_{buffer}$ is set too high (e.g., 500ms) to prevent starvation, the UI is no longer "live," which is unacceptable for real-time applications like Air Traffic Control or Conjunction monitoring.

#### Remediations:
* **Adaptive Jitter Buffer**: Dynamically adjust $\Delta t_{buffer}$ based on the rolling standard deviation of network arrival times ($\sigma_{network}$):
  $$\Delta t_{buffer} = 3 \cdot \sigma_{network} + \Delta t_{batch}$$
* **Intra-Batch Spline Extrapolation**: If the queue starves, transition smoothly from interpolation to linear dead reckoning (extrapolation) using the last known velocity vector, applying a damping factor to decelerate the node if the starvation persists.

---

### 2.2. Out-of-Sequence Packet Spline Invalidation

When a late packet ($t_{packet} \ge t_{play} - t_{threshold}$) arrives, the proposal marks the spline segment as dirty and triggers local recalculation.

#### The Flaws:
1. **Tearing during Interpolation**: The main thread reads spline coefficients to interpolate positions. If the worker recalculates coefficients on the same array in place, the main thread can read a mixture of old and new coefficients.
2. **Spline Boundary Discontinuity**: Recalculating a cubic spline segment $[t_k, t_{k+1}]$ alters the tangent vectors $\mathbf{V}_k$ and $\mathbf{V}_{k+1}$. This modification propagates to adjacent segments $[t_{1-k}, t_k]$ and $[t_{k+1}, t_{k+2}]$. If only the immediate segment is marked dirty, the path will have sharp angles (discontinuous first derivative $\mathcal{C}^1$ continuity loss) at the boundary nodes, causing visual jumps.

#### Remediations:
* **Double-Buffered Coefficient Trees**: Read spline coefficients from an immutable buffer. When a recalculation occurs, generate a new buffer and swap the reference atomically.
* **Extended Invalidation Window**: When a segment is modified, invalidate and recalculate tangents for the $N-1$ and $N+1$ neighboring segments to preserve $\mathcal{C}^1$ (velocity) and $\mathcal{C}^2$ (acceleration) continuity.

---

## 3. Concurrency Memory Model Auditing: React Web Worker Transfers

### 3.1. Double-Buffered Transferable ArrayBuffer Lifecycles

If `SharedArrayBuffer` is disabled (missing COOP/COEP headers), the proposal recommends transferring `ArrayBuffers` between the Worker and UI thread using a double-buffered queue (`Buffer_A` and `Buffer_B`).

#### The Flaws:
1. **Neutering Lock & Starvation**: When `postMessage(payload, [Buffer_A])` is called, `Buffer_A` is instantly neutered on the worker. The worker cannot write any new telemetry to it.
2. **Asymmetric Consumer/Producer Speeds**: If the UI thread drops a frame (e.g., during layout recalculation or heavy rendering) and fails to return `Buffer_A` via `postMessage` in time, the worker only has `Buffer_B`. In the next tick, the worker fills and transfers `Buffer_B`. Now both buffers are held by the UI thread. The worker has **zero** buffers left.
3. **Fallback GC Thrashing**: If the worker runs out of buffers in its pool, it must allocate a new `ArrayBuffer`. Under sustained UI lag, this causes the worker to allocate buffers continuously, which are then transferred, rendered, and discarded, triggering severe Garbage Collection (GC) pauses on the main thread.

#### Remediations:
* **Circular Buffer Ring Pool**: Maintain a pool of 4-5 pre-allocated buffers.
* **Backpressure Control**: If the worker detects that all buffers are currently in flight, it must queue incoming telemetry in a raw, compact array structure on the worker, rather than allocating new transferable buffers. Once a buffer is returned, the worker flushes the backlog into it.

---

## 4. Concurrency Memory Model Auditing: Flutter Dart FFI Native Heap

### 4.1. Use-After-Free (UAF), Double-Free, and Native Memory Leaks

Dart Isolates do not share a garbage collector. The proposal suggests allocating coordinate buffers on the native C-heap via `dart:ffi` and passing raw memory pointers (`Pointer<Double>`) between isolates.

#### The Flaws:
1. **Implicit Memory Leak**: Standard Dart FFI memory allocations (`malloc.allocate()`) are completely invisible to the Dart VM's GC. If the wrapper class holding the `Pointer` goes out of scope on either isolate, the raw C-heap allocation is leaked. Over time, telemetry streams will exhaust the system's RAM.
2. **Double Free / Use-After-Free**: If the background isolate allocations are passed to the UI isolate, there is no language-enforced ownership. If the background isolate frees the pointer (thinking it allocated it), and the UI isolate attempts to read or write to it during a frame render, a segmentation fault or memory corruption occurs. If both isolates call `free()`, the application crashes.
3. **No Finalizers**: In Dart, finalizers are needed to clean up native resources. If the proposal does not mandate registering pointers with a `NativeFinalizer`, any crash or unhandled exception in the Dart isolate will bypass manual `malloc.free()` calls, leaking the buffer permanently.

#### Remediations:
* **NativeFinalizer Integration**: Attach a `NativeFinalizer` linked to the C `free` function to the Dart wrapper object on the isolate that owns the memory lifecycle:
  ```dart
  class NativeCoordinates {
    final Pointer<Double> ptr;
    static final _finalizer = NativeFinalizer(posixFree.cast());
    
    NativeCoordinates(this.ptr) {
      _finalizer.attach(this, ptr.cast(), detach: this);
    }
  }
  ```
* **Strict Single-Isolate Ownership**: Designate the Background Isolate as the sole owner of the memory. The UI Isolate must only treat the pointer as read-only and must never free it. When a track is destroyed, the Background Isolate is responsible for freeing the pointer after receiving an acknowledgment from the UI Isolate.

---

### 4.2. Data Racing and Visual Tearing

Passing raw C-heap pointers between isolates allows concurrent read/write access without Dart VM protection.

#### The Flaws:
1. **Coordinate Tearing**: If the Background Isolate is writing new coordinates for a spacecraft (e.g., $(X, Y, Z)$) at the same time the UI Isolate is copying that data to the GPU vertex buffer, the UI thread could read $X$ and $Y$ from frame $N$, and $Z$ from frame $N+1$. This results in a temporary, highly anomalous coordinate value, causing the spacecraft to "blink" or jump to a wrong position for a single frame.

#### Remediations:
* **Double-Buffered Pointer Swapping (Flipped Buffer)**: Allocate two separate C-heap blocks per track. The background isolate writes to Buffer 0, then updates an atomic pointer index. The UI isolate reads from the index that is NOT currently being written to.
* **Atomic Flags / Spinlocks**: Use C-level atomic flags (`std::atomic_flag` or `atomic_uint32_t`) via FFI to signal when a buffer is locked by the renderer.

---

### 4.3. Impeller HAL Memory Alignment Constraints

Impeller (Flutter's rendering engine) communicates with Metal/Vulkan. 

#### The Flaws:
1. **Alignment Violations**: GPU drivers have strict alignment constraints for memory access:
   - Metal and Vulkan require uniform buffers to be aligned to device-specific limits (typically 16, 64, or 256 bytes).
   - Direct memory sharing of raw C arrays from Dart FFI into Impeller vertex/storage structures will crash the GPU driver (e.g., `Device Lost` or `Invalid Alignment` validation errors) if the pointers are not aligned to these boundaries.

#### Remediations:
* **Aligned Allocation**: Avoid standard `malloc`. Use platform-specific aligned memory allocators like `posix_memalign` (macOS/Linux) or `_aligned_malloc` (Windows) to guarantee 256-byte alignment for all shared buffers.
  ```c
  void* ptr;
  int res = posix_memalign(&ptr, 256, size);
  ```

---

## 5. WGSL Struct Alignments & WebGPU Resource Leakage

### 5.1. Struct Alignment and Padding Validation Failures

The proposal defines several WGSL structures:
```wgsl
struct ConjunctionPair {
    object_a: u32,
    object_b: u32,
    distance: f32,
}
struct ConjunctionOutput {
    counter: atomic<u32>,
    pairs: array<ConjunctionPair, 1024>,
}
```

#### The Flaws:
1. **Array Element Stride Rules**: Under WGSL alignment rules, the size and alignment of a struct are determined by its members.
   - `ConjunctionPair` contains three 32-bit scalars (`u32`, `u32`, `f32`), totaling 12 bytes.
   - If used inside an array `array<ConjunctionPair, 1024>`, the stride of the array will be 12 bytes.
   - However, if the struct is used within a Uniform Buffer, the alignment of the structure is promoted to 16 bytes, and the layout will fail compilation or read incorrect values on the CPU if the CPU array layout assumes a dense packing of 12 bytes per element.
2. **CPU-GPU Memory Layout Mismatch**: On the CPU (JavaScript/TypeScript), developers often map this buffer to a float/int array. If Javascript reads:
   ```typescript
   const pairs = new Uint32Array(arrayBuffer);
   const distance = new Float32Array(arrayBuffer);
   ```
   If the compiler pads `ConjunctionPair` to 16 bytes (which happens if it is placed in a Uniform block or if a 16-byte aligned type like `vec3` or `vec4` is added later), the Javascript indices will be misaligned, leading to silent data corruption.

#### Remediations:
* **Explicit Padding**: Always pad structures to 16-byte boundaries manually in the WGSL definition and CPU structures:
  ```wgsl
  struct ConjunctionPair {
      object_a: u32,
      object_b: u32,
      distance: f32,
      _pad: u32, // Explicit 4-byte padding to guarantee 16-byte size
  }
  ```
* **Avoid Mixing Float/Int in Dense Arrays**: Use parallel flat arrays (e.g., one buffer for `indices: vec2<u32>` and another for `distances: f32`) instead of mixed structures. This matches JavaScript TypedArray layouts (`Uint32Array` vs `Float32Array`) and prevents alignment mismatches.

---

### 5.2. WebGPU/Impeller VRAM Resource Leakage

For dynamic telemetry (e.g., planes entering/leaving radar range, satellites passing over), the viewport must continuously instantiate and destroy tracks.

#### The Flaws:
1. **Unmanaged GPU Buffers**: In WebGPU, buffers (`GPUDevice.createBuffer()`) and textures are not garbage-collected when the JS reference goes out of scope. They remain allocated in VRAM until `destroy()` is called. The proposal does not define a VRAM allocation tracking mechanism, leading to rapid GPU memory exhaustion.
2. **Inactive Buffer Mapping Errors**: When calling `mapAsync()` for picking or conjunction readbacks, if a track is deleted from the scene graph before the map callback resolves, calling `unmap()` on the destroyed buffer throws WebGPU errors, polluting the console and potentially crashing the rendering loop.

#### Remediations:
* **Resource Registry and Disposal Pool**: Wrap all WebGPU resource creations in a manager that tracks active buffers. Implement a strict `.dispose()` lifecycle method on the coordinate engine.
* **Buffer Recycling (Pooling)**: Never dynamically create/destroy buffers for short-lived tracks. Instead, allocate a large, static **GPURingBuffer** (VertexBuffer / StorageBuffer) and allocate/deallocate slices of the buffer using offset pointers, avoiding GPU allocations during runtime.

---

## 6. Actionable Remediations & Architectural Design Patterns

To resolve the audited bugs, the following structural improvements should be added to the proposal:

### 6.1. The Phase-Locked Loop (PLL) Time Controller (Replaces PID)

Implement playback rate adjustment using a digital PLL with a loop filter:

```javascript
class PlaybackPLL {
  constructor(bufferDelay) {
    this.bufferDelay = bufferDelay;
    this.t_play = 0;
    this.phaseErrorAccumulator = 0;
    this.kp = 0.1; // Loop gain proportional
    this.ki = 0.01; // Loop gain integral
  }

  update(t_stream_max, dt_wall) {
    const t_target = t_stream_max - this.bufferDelay;
    const error = t_target - this.t_play;

    // Freeze integrator during large discontinuities (boundary reset)
    if (Math.abs(error) > 1000) { // 1 second threshold
      this.t_play = t_target;
      this.phaseErrorAccumulator = 0;
      return 1.0; // Return nominal speed
    }

    this.phaseErrorAccumulator += error * dt_wall;
    
    // Anti-windup clamping on integral component
    const maxAccumulator = 5.0 / this.ki;
    this.phaseErrorAccumulator = Math.max(-maxAccumulator, Math.min(maxAccumulator, this.phaseErrorAccumulator));

    const rate = 1.0 + (this.kp * error) + (this.ki * this.phaseErrorAccumulator);
    
    // Strict rate bounding
    const clampedRate = Math.max(0.90, Math.min(1.10, rate));
    
    this.t_play += clampedRate * dt_wall;
    return clampedRate;
  }
}
```

### 6.2. Double-Buffered Pointer Swap Protocol for Dart FFI

Ensure atomic swaps of FFI coordinate arrays between isolates:

```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

class DoubleBufferedCoordinates {
  final Pointer<Double> buffer0;
  final Pointer<Double> buffer1;
  
  // 0 = UI reads buffer0, Worker writes buffer1
  // 1 = UI reads buffer1, Worker writes buffer0
  final Pointer<Uint32> activeReadIndex;

  DoubleBufferedCoordinates(int count)
      : buffer0 = malloc.allocate<Double>(count * sizeOf<Double>()),
        buffer1 = malloc.allocate<Double>(count * sizeOf<Double>()),
        activeReadIndex = malloc.allocate<Uint32>(sizeOf<Uint32>()) {
    activeReadIndex.value = 0;
  }

  Pointer<Double> get writeBuffer => activeReadIndex.value == 0 ? buffer1 : buffer0;
  Pointer<Double> get readBuffer => activeReadIndex.value == 0 ? buffer0 : buffer1;

  void swap() {
    // Atomic store/swap (simulated via FFI or native library)
    activeReadIndex.value = activeReadIndex.value == 0 ? 1 : 0;
  }

  void free() {
    malloc.free(buffer0);
    malloc.free(buffer1);
    malloc.free(activeReadIndex);
  }
}
```
