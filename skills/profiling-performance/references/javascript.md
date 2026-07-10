# JavaScript/Node Language Pack for `hyperpowers:profiling-performance`

This reference provides JavaScript/Node-specific profilers, V8 JIT strategies, GC-awareness, and event-loop optimization patterns. It supplements the agnostic `profiling-performance` skill spine — do not duplicate the general workflow here; reference it instead.

## Profiling Tools

Group tools by what they measure, not by "sampling vs. instrumentation" — the common Node CPU profilers are all sampling-based; they differ in output format and which layer of the stack they surface.

**(a) CPU sampling profilers** (statistical stack sampling — low overhead, no code changes):
- **`node --prof`** (built-in V8 tick profiler) — samples the stack, no instrumentation
  - `node --prof script.js` → generates `isolate-*-v8.log`
  - `node --prof-process isolate-*-v8.log > profile.txt` — human-readable report
  - Shows ticks (samples) per function, native vs. JS time
- **`--cpu-prof`** (built-in) — sampling CPU profile without attaching a debugger
  - `node --cpu-prof script.js` → generates `.cpuprofile` (open in Chrome DevTools)
  - Same sampling engine the DevTools CPU profiler uses; convenient for production-like runs
- **`0x`** — sampling flamegraph profiler for Node
  - `0x script.js` — generates an interactive flamegraph in the browser
  - Good for spotting the widest (hottest) stacks visually
- **`clinic flame`** — sampling flamegraph (part of the Clinic suite)
  - `clinic flame -- node script.js`
- **Chrome DevTools CPU profiler / `--inspect`** — sampling CPU profiler behind a visual UI
  - `node --inspect script.js` or `node --inspect-brk script.js` (pauses at start), then open `chrome://inspect`
  - Same sampling profiler as `--cpu-prof`, with an interactive UI

**(b) Heap / allocation profilers** (memory, not CPU time):
- **`--heap-prof`** (built-in) — sampling heap allocation profile without a debugger
  - `node --heap-prof script.js` → generates `.heapprofile` (open in Chrome DevTools)
- **Chrome DevTools heap snapshots / allocation timeline** (via `--inspect`) — retained-size analysis, leak hunting, allocation sites
  - Use for "what is holding memory" and "where are allocations coming from" questions

**(c) Async / event-loop diagnostics** (not CPU sampling — they surface where async time and event-loop delay go):
- **`clinic doctor`** — flags event-loop delay, I/O waits, GC pressure, and points you at the likely bound
  - `clinic doctor -- node script.js`
  - Good first move to decide I/O-bound vs. event-loop-blocked vs. compute-bound
- **`clinic bubbleprof`** — visualizes async operations and where async delay accumulates
  - `clinic bubbleprof -- node script.js`
- **`perf_hooks.monitorEventLoopDelay()`** — quantifies event-loop lag as a histogram
  ```javascript
  const { monitorEventLoopDelay } = require('perf_hooks');
  const histogram = monitorEventLoopDelay({ resolution: 10 });
  histogram.enable();
  // ... run workload ...
  console.log(histogram.percentiles);
  ```

**(d) Timers / microbenchmarks** (measure a specific snippet, not a whole program):
- **`performance.now()`** (built-in `perf_hooks`) — high-resolution timestamps
  ```javascript
  const { performance } = require('perf_hooks');
  const start = performance.now();
  expensiveOperation();
  console.log(`Took ${performance.now() - start} ms`);
  ```
- **`Benchmark.js`** — mature microbenchmarking library (handles warmup, iteration, statistical analysis)

**Choosing:**
- Start with **`clinic doctor`** to decide I/O vs. compute vs. event-loop bottlenecks
- For a compute-bound hot path, reach for a **CPU sampling profiler** — `--cpu-prof`, `0x`, or `clinic flame`
- For memory growth or leaks, use a **heap/allocation profiler** — `--heap-prof` or DevTools heap snapshots
- For async/event-loop delay, use **`clinic bubbleprof`** or **`monitorEventLoopDelay()`**
- Use **Chrome DevTools (`--inspect`)** when you want an interactive UI over the same CPU/heap data

## The V8 JIT (Just-In-Time Compiler)

V8 optimizes hot code with a multi-tier JIT. Understanding how it works helps avoid performance cliffs.

**Key concepts:**
1. **Monomorphic vs. polymorphic vs. megamorphic call sites**
   - **Monomorphic** — function called with a single object shape (hidden class); monomorphic sites *tend* to optimize and inline well
   - **Polymorphic** — called with a few (roughly 2-4) shapes; still optimizable, often with somewhat less benefit
   - **Megamorphic** — called with many shapes; the inline cache *can* fall back to a slower generic path and optimization quality *can* drop
   - **Mitigation (when profiling shows a hot polymorphic/megamorphic site):** keep object shapes stable, pass consistent types to hot functions

2. **Hidden classes (object shapes)**
   - V8 tracks object shapes via hidden classes
   - Objects with the same property names in the same order tend to share a hidden class
   - Adding/deleting properties in different orders creates new hidden classes, which *can* push a call site toward polymorphic/megamorphic behavior
   - **Best practices:**
     - Initialize all properties in the constructor in a consistent order
     - Avoid `delete` on hot-path objects (set the property to `undefined` instead, or use `Map`)
     - Avoid adding properties after construction in hot paths

3. **Deoptimization (deopts)**
   - V8 speculatively optimizes based on observed types
   - If assumptions are violated (e.g., a function suddenly gets a different type), V8 deoptimizes
   - Repeated deopt/reopt cycles *can* be costly *when profiling confirms they sit in the hot path*
   - **Mitigation:** keep types stable in hot functions, avoid passing `null`/`undefined` unexpectedly

**Debugging JIT issues:**
- **`--trace-opt` / `--trace-deopt`** — log optimizations and deoptimizations (still valid flags)
  - `node --trace-opt --trace-deopt script.js`
  - Identifies deopt reasons (e.g., "Wrong map", "Not a Smi")
- **Inline-cache tracing is version-dependent.** Older `--trace-ic` has been removed in current Node/V8; the equivalent is now `--log-ic`. Check what your build supports before relying on either:
  - `node --v8-options | rg 'trace-ic|log-ic'` — lists the flags this build actually accepts
  - Use `--log-ic` where available to trace inline-cache state (monomorphic → polymorphic → megamorphic)

**Guidance:**
- Frame these as *tendencies*, not guarantees — V8 internals evolve, and behavior varies by workload
- Only hand-tune for V8 internals if profiling shows JIT cliffs (megamorphic sites, repeated deopts)
- Prefer clear, maintainable code; apply V8-specific tricks only where measured

## GC Pressure (Garbage Collection)

Node uses V8's generational GC. Excessive allocations cause GC pauses.

**Common sources of GC pressure:**
- **Short-lived allocations in hot loops** — temporary objects, array copies
- **Closures capturing large scopes** — the closure holds references to entire parent scope, preventing GC
- **String concatenation in loops** — `str += x` reallocates each time; use array + `join()` or template literals
- **Repeated `JSON.parse` / `JSON.stringify`** in hot paths

**Mitigation strategies:**
1. **Reuse buffers** instead of allocating new ones
   ```javascript
   // Bad: allocates every iteration
   for (let i = 0; i < n; i++) {
     const buf = Buffer.alloc(1024);
     process(buf);
   }
   
   // Better: reuse buffer
   const buf = Buffer.alloc(1024);
   for (let i = 0; i < n; i++) {
     process(buf);
   }
   ```

2. **Consider typed arrays for large homogeneous numeric buffers** — `Float64Array`, `Int32Array`, etc.
   - Contiguous, fixed-layout memory; useful for binary data and native/WASM interop (zero-copy)
   - Not a guaranteed GC win: V8 can already store ordinary numeric arrays as unboxed Smi/double elements (not boxed `Number` objects), so a plain `Array` of numbers is often not paying a per-element boxing cost. Treat typed arrays as a *measured* option for stable-layout numeric buffers, not a blanket replacement — profile before switching

3. **Avoid creating closures in hot loops**
   ```javascript
   // Bad: creates new closure every iteration
   for (let i = 0; i < n; i++) {
     arr.forEach(x => process(x, i));
   }
   
   // Better: hoist closure or use for-of
   for (let i = 0; i < n; i++) {
     for (const x of arr) {
       process(x, i);
     }
   }
   ```

4. **Object pooling** — reuse objects instead of allocating/freeing
   - Useful for high-allocation-rate services
   - Tradeoff: complexity vs. GC reduction

**Monitoring GC:**
- **`--trace-gc`** — log GC events
  - `node --trace-gc script.js`
- **`--expose-gc` + `process.memoryUsage()`** — manual GC trigger and memory stats
- **Heap snapshots** via Chrome DevTools (`--inspect`) or `--heap-prof`

## Event Loop / Async

**Core principle:** Node is single-threaded for JavaScript execution. The event loop multiplexes I/O concurrency, NOT CPU parallelism.

**Key rules:**
1. **Don't block the event loop** — any synchronous CPU work or blocking I/O freezes the entire loop
   - Avoid synchronous FS operations (`fs.readFileSync`, `fs.writeFileSync`) in production
   - Avoid long-running synchronous compute in request handlers
2. **Offload CPU-bound work to `worker_threads`** — true parallelism for compute
   ```javascript
   const { Worker } = require('worker_threads');
   const worker = new Worker('./compute-worker.js', { workerData: input });
   worker.on('message', result => { /* handle */ });
   ```
3. **Many Node bottlenecks are I/O- or event-loop-bound, not compute-bound** — apply the spine's bound axis first
   - If `clinic doctor` shows event-loop delays or I/O waits, parallelizing compute won't help
   - Fix: batching, async I/O, reducing syscalls
4. **Measure event-loop lag** with `perf_hooks.monitorEventLoopDelay()` to diagnose blocking

**Async patterns:**
- Prefer `async`/`await` over raw Promises for readability
- Use `Promise.all()` for concurrent independent async operations
- Avoid `await` in tight loops when operations can run concurrently
  ```javascript
  // Bad: sequential (slow)
  for (const id of ids) {
    await fetchUser(id);
  }
  
  // Better: concurrent (fast)
  await Promise.all(ids.map(id => fetchUser(id)));
  ```

## Typed Arrays for Numeric Work (Optional)

For compute-heavy numeric kernels:
- **`Float64Array`, `Int32Array`, etc.** — contiguous, fixed-element-type memory
  - Predictable, stable layout for large homogeneous numeric buffers
  - Can be passed to WebAssembly or native modules zero-copy (a common reason to reach for them)
  - **Not automatically lower GC pressure than a plain numeric `Array`:** V8 can store ordinary numeric arrays as unboxed Smi/double elements, so an `Array` of numbers is often not paying per-element boxing. The typed-array wins are the fixed layout, binary/interop compatibility, and cache predictability — confirm any allocation/GC benefit by measuring

**When to use:**
- Large homogeneous numeric buffers with a stable layout
- Binary data handling and native/WASM interop
- Numeric hot loops where a profiler shows the plain-array path is the bottleneck

**When NOT to use:**
- General application logic (arrays of objects, mixed types)
- As a reflexive "faster than `Array`" swap — measure first; the plain-array path may already be unboxed

## Example: Identifying and Fixing a Slow Node Function

**Scenario:** a request handler is slow.

1. **Profile with `clinic doctor`** — identify if it's I/O-bound, event-loop-blocked, or compute-bound
2. **If event-loop-blocked:** look for synchronous I/O or long synchronous compute; offload to `worker_threads` or make async
3. **If I/O-bound:** check for serial I/O that could be concurrent, excessive syscalls, or missing caching
4. **If compute-bound:** profile with `0x` or `--cpu-prof` to find hot functions
   - Check for deopts (`--trace-deopt`); for inline-cache state, use `--log-ic` where your build supports it (`node --v8-options | rg 'trace-ic|log-ic'`)
   - Check for GC pressure (`--trace-gc`)
   - Consider typed arrays for large stable-layout numeric buffers (measure first)
   - Consider `worker_threads` for parallelizable compute

**JavaScript/Node-specific candidate families** (not a fixed priority order — rank them by the measured bound per the agnostic spine's ranking rule):
- Algorithmic change (O(n²) → O(n log n))
- Unblock the event loop (async I/O, offload CPU work to `worker_threads`)
- Reduce I/O round-trips (batching, caching, concurrent operations)
- Reduce allocations (buffer reuse, object pooling, avoid closures in hot loops)
- V8 JIT optimization (monomorphic call sites, stable object shapes, avoid deopts)
- Typed arrays for numeric hot paths
- Micro-opts (loop unrolling, manual inlining — measure first)

## Common Node.js Performance Anti-Patterns

**STOP if you see:**
- **Synchronous FS in production** (`fs.readFileSync`, `fs.writeFileSync`) — blocks event loop
- **CPU-heavy work in request handler** — offload to `worker_threads`
- **Sequential `await` in loops** when operations are independent — use `Promise.all()`
- **String concatenation in loops** — use array + `join()` or template literals
- **Deleting properties in hot paths** — sets to `undefined` or use `Map`
- **Creating closures in hot loops** — hoist or restructure
- **Unmonitored event-loop lag** — use `clinic doctor` or `perf_hooks.monitorEventLoopDelay()`

## Tooling Notes

**Install profilers:**
```bash
npm install -g 0x clinic
```

**Quick command reference:**
```bash
# CPU sampling profilers
node --prof script.js && node --prof-process isolate-*-v8.log > profile.txt
node --cpu-prof script.js   # generates .cpuprofile (open in Chrome DevTools)
0x script.js
clinic flame -- node script.js    # sampling flamegraph

# Heap / allocation profilers
node --heap-prof script.js  # generates .heapprofile

# Async / event-loop diagnostics
clinic doctor -- node script.js      # I/O vs. compute vs. event-loop
clinic bubbleprof -- node script.js  # async/event-loop delay

# Chrome DevTools (interactive UI over the same CPU/heap data)
node --inspect script.js
# Open chrome://inspect

# JIT debugging
node --trace-opt --trace-deopt script.js
node --v8-options | rg 'trace-ic|log-ic'   # check inline-cache flags this build supports
# then, where available:
node --log-ic script.js

# GC monitoring
node --trace-gc script.js
```

**Interpreting output:**
- **`--prof-process`** — look for functions with high `ticks` count (samples)
- **Flamegraphs** — wider bars = more time; focus on widest stacks
- **`clinic doctor`** — red/orange warnings indicate event-loop issues or I/O bottlenecks
- **`--trace-deopt`** — repeated deopts on same function = type instability
