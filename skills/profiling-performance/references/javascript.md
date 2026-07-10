# JavaScript/Node Language Pack for `hyperpowers:profiling-performance`

This reference provides JavaScript/Node-specific profilers, V8 JIT strategies, GC-awareness, and event-loop optimization patterns. It supplements the agnostic `profiling-performance` skill spine — do not duplicate the general workflow here; reference it instead.

## Profiling Tools

**Sampling profilers (lower overhead, no code changes):**
- **`node --prof`** (built-in V8 profiler) — sampling profiler, no instrumentation
  - `node --prof script.js` → generates `isolate-*-v8.log`
  - `node --prof-process isolate-*-v8.log > profile.txt` — human-readable report
  - Shows ticks (samples) per function, native vs. JS time
- **`0x`** — flamegraph profiler for Node
  - `0x script.js` — generates flamegraph in browser
  - Visual sampling-based profiler, good for identifying hot functions
- **`clinic` suite** — comprehensive Node.js profiling toolkit
  - **`clinic doctor`** — detects event-loop issues, I/O bottlenecks
  - **`clinic flame`** — flamegraph profiler
  - **`clinic bubbleprof`** — async operations and event-loop delays
  - `clinic doctor -- node script.js`
  - Identifies if you're I/O-bound, event-loop-blocked, or compute-bound

**Instrumentation profilers (higher overhead, precise call counts):**
- **Chrome DevTools / `--inspect`** — full debugging/profiling UI
  - `node --inspect script.js` or `node --inspect-brk script.js` (pauses at start)
  - Open `chrome://inspect` in Chrome
  - CPU profiler, heap snapshots, memory profiler
  - Good for deep dives with visual UI
- **`--cpu-prof` / `--heap-prof`** (built-in) — generates CPU/heap profiles without debugger
  - `node --cpu-prof script.js` → generates `.cpuprofile` (open in Chrome DevTools)
  - `node --heap-prof script.js` → generates `.heapprofile`
  - Lower overhead than `--inspect`, useful for production-like profiling

**Microbenchmarking:**
- **`performance.now()`** (built-in `perf_hooks`) — high-resolution timestamps
  ```javascript
  const { performance } = require('perf_hooks');
  const start = performance.now();
  expensiveOperation();
  console.log(`Took ${performance.now() - start} ms`);
  ```
- **`Benchmark.js`** — mature microbenchmarking library (handles warmup, iteration, statistical analysis)
- **`perf_hooks.monitorEventLoopDelay()`** — measure event-loop lag
  ```javascript
  const { monitorEventLoopDelay } = require('perf_hooks');
  const histogram = monitorEventLoopDelay({ resolution: 10 });
  histogram.enable();
  // ... run workload ...
  console.log(histogram.percentiles);
  ```

**Choosing:**
- Start with **`clinic doctor`** to identify I/O vs. compute vs. event-loop bottlenecks
- Use **`0x`** or **`clinic flame`** for CPU-bound sampling flamegraphs
- Use **`--cpu-prof`** for CPU profiling without a debugger
- Use **Chrome DevTools (`--inspect`)** for deep dives with heap snapshots and memory profiling
- Use **`clinic bubbleprof`** for async/event-loop analysis

## The V8 JIT (Just-In-Time Compiler)

V8 optimizes hot code with a multi-tier JIT. Understanding how it works helps avoid performance cliffs.

**Key concepts:**
1. **Monomorphic vs. polymorphic vs. megamorphic call sites**
   - **Monomorphic** — function called with single object shape (hidden class); fastest, V8 inlines and optimizes aggressively
   - **Polymorphic** — called with 2-4 shapes; slower, still optimizable
   - **Megamorphic** — called with 5+ shapes; V8 gives up on inline caching, much slower
   - **Mitigation:** keep object shapes stable, pass consistent types to hot functions

2. **Hidden classes (object shapes)**
   - V8 tracks object shapes via hidden classes
   - Objects with same property names in same order share a hidden class
   - Adding/deleting properties in different orders creates new hidden classes → megamorphic code
   - **Best practices:**
     - Initialize all properties in constructor in consistent order
     - Avoid `delete` on hot-path objects (sets property to `undefined` instead, or use `Map`)
     - Avoid adding properties after construction in hot paths

3. **Deoptimization (deopts)**
   - V8 speculatively optimizes based on observed types
   - If assumptions violated (e.g., function suddenly gets different type), V8 deoptimizes
   - Repeated deopt/reopt cycles destroy performance
   - **Mitigation:** keep types stable in hot functions, avoid passing `null`/`undefined` unexpectedly

**Debugging JIT issues:**
- **`--trace-opt` / `--trace-deopt`** — log optimizations and deoptimizations
  - `node --trace-opt --trace-deopt script.js`
  - Identifies deopt reasons (e.g., "Wrong map", "Not a Smi")
- **`--trace-ic`** — trace inline cache state (monomorphic → polymorphic → megamorphic)

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

2. **Use typed arrays for numeric work** — `Float64Array`, `Int32Array`, etc.
   - Contiguous memory, better cache locality
   - Less GC pressure than arrays of boxed numbers

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
- **`Float64Array`, `Int32Array`, etc.** — contiguous typed memory
  - Better cache locality than arrays of boxed numbers
  - Can be passed to WebAssembly or native modules zero-copy
  - Less GC pressure

**When to use:**
- Numeric hot loops (math-heavy, simulation, DSP, etc.)
- Large numeric datasets

**When NOT to use:**
- General application logic (arrays of objects, mixed types)
- Premature optimization — measure first

## Example: Identifying and Fixing a Slow Node Function

**Scenario:** a request handler is slow.

1. **Profile with `clinic doctor`** — identify if it's I/O-bound, event-loop-blocked, or compute-bound
2. **If event-loop-blocked:** look for synchronous I/O or long synchronous compute; offload to `worker_threads` or make async
3. **If I/O-bound:** check for serial I/O that could be concurrent, excessive syscalls, or missing caching
4. **If compute-bound:** profile with `0x` or `--cpu-prof` to find hot functions
   - Check for megamorphic call sites (`--trace-ic`) or deopts (`--trace-deopt`)
   - Check for GC pressure (`--trace-gc`)
   - Consider typed arrays for numeric work
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
# Sampling profilers
node --prof script.js && node --prof-process isolate-*-v8.log > profile.txt
0x script.js

# Clinic suite
clinic doctor -- node script.js   # I/O vs. compute vs. event-loop
clinic flame -- node script.js    # flamegraph
clinic bubbleprof -- node script.js  # async/event-loop

# CPU/heap profiles (no debugger)
node --cpu-prof script.js   # generates .cpuprofile
node --heap-prof script.js  # generates .heapprofile

# Chrome DevTools
node --inspect script.js
# Open chrome://inspect

# JIT debugging
node --trace-opt --trace-deopt script.js
node --trace-ic script.js

# GC monitoring
node --trace-gc script.js
```

**Interpreting output:**
- **`--prof-process`** — look for functions with high `ticks` count (samples)
- **Flamegraphs** — wider bars = more time; focus on widest stacks
- **`clinic doctor`** — red/orange warnings indicate event-loop issues or I/O bottlenecks
- **`--trace-deopt`** — repeated deopts on same function = type instability
