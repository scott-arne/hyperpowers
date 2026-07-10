# C++ Language Pack for `hyperpowers:profiling-performance`

This reference provides C++-specific profilers, compiler flags, vectorization strategies, and modern C++ tools for performance optimization. It supplements the agnostic `profiling-performance` skill spine — do not duplicate the general workflow here; reference it instead.

This pack is C++-standard-agnostic. Detect the project's `-std` (or ask), and prefer the most modern construct it supports — feature annotations below note the minimum standard so suggestions degrade gracefully on older toolchains.

## Profiling Tools

**Sampling profilers:**
- `perf` (Linux) — hardware counters, cache misses, branch mispredicts
  - `perf record ./program` → `perf report`
  - `perf stat -d` for cache-miss rates and IPC
- Intel VTune (cross-platform, commercial) — deep microarchitecture analysis
- Apple Instruments (macOS) — Time Profiler, Allocations, System Trace
- Callgrind (Valgrind suite) — call-graph profiling

**Microbenchmarking:**
- **Google Benchmark** (preferred) — handles warmup, iteration, `DoNotOptimize`/`ClobberMemory` to prevent dead-code elimination
  ```cpp
  static void BM_MyKernel(benchmark::State& state) {
    for (auto _ : state) {
      benchmark::DoNotOptimize(compute_kernel(data));
    }
  }
  BENCHMARK(BM_MyKernel);
  ```

## Compiler Flags

**Safe baseline:** `-O3 -march=native` (or specific `-march`/`-mtune` for deployment target). Consider `-flto` for link-time optimization.

### The `-ffast-math` / `-Ofast` Warning

**`-ffast-math` (and `-Ofast`, which implies it) changes results.** It bundles several standard-violating assumptions:
- `-ffinite-math-only` (assumes no NaN/Inf — reachable ones now produce garbage)
- `-fassociative-math` (reorders floating-point operations, so sums/reductions round differently)
- `-fno-signed-zeros`, `-freciprocal-math`
- Denormal flush-to-zero on some targets
- Defines `__FAST_MATH__`, which can change library behavior

**Guidance:** **Do not enable globally by default** for code where correctness or reproducibility matters. If your human partner wants the speed, apply it *surgically*:
- A single translation unit or function via `[[gnu::optimize("fast-math")]]` / pragmas
- Pick components à la carte where possible (e.g., just `-fno-math-errno`)
- **Re-run the correctness baseline** from the agnostic skill's step 1 to confirm tolerance still holds

Always name this tradeoff explicitly rather than slipping `-ffast-math` into a recommended flag list.

## Autovectorization

**Help the compiler autovectorize before hand-writing SIMD:**

1. **Clean countable loops** — range-for or `for (size_t i = 0; i < n; ++i)` with known bounds
2. **No aliasing surprises** — use `__restrict__` pointers, or `std::assume_aligned` (C++20)
3. **No loop-carried dependencies** you don't need

**Verify it actually vectorized** — don't assume. Check compiler reports:
- **Clang:** `-Rpass=loop-vectorize -Rpass-missed=loop-vectorize`
- **GCC:** `-fopt-info-vec[-missed]`

A loop you *thought* was SIMD but isn't is a common silent miss.

## Explicit Vectorization (Only If Autovectorization Left Performance on the Table)

Climb this ladder; each rung costs portability/maintainability, so stop as soon as the goal is met:

1. **Better data layout + hints** so the compiler autovectorizes (revisit data layout and flags)
2. **Portable SIMD abstraction:**
   - `std::simd` (C++26) / `std::experimental::simd` today
   - Google Highway or xsimd
   - For linear algebra: Eigen, BLAS/LAPACK, MKL (almost always faster and validated)
3. **Raw intrinsics** (AVX2/AVX-512/NEON) as last resort
   - Gate behind runtime dispatch or `#ifdef` to avoid illegal-instruction crashes on older hardware

## Branch and Instruction-Level Tuning (Last, and Only Where Measured)

**First check whether the branch survives compilation:**
- At `-O3` the compiler routinely if-converts small conditionals into `cmov` or folds them into vectorized masked/blended loops
- Look for `cmov` in the asm or a "loop vectorized" note **before** touching it
- The famous "sorted array beats unsorted" effect largely vanishes once the branch is if-converted
- On memory-bound loops, branch tricks are moot regardless — you're waiting on memory, not the branch unit

**Branchless rewrites** (`std::min/max`, masking, arithmetic selects) help mainly for:
- **Unpredictable, data-dependent** branches the compiler left as real branches
- Modern predictors handle predictable branches essentially for free — converting those to branchless can be *slower*
- Measure before and after, on representative data (predictability depends on input distribution)

**Other micro-tuning:**
- `[[likely]]`/`[[unlikely]]` (C++20) or `__builtin_expect` for genuinely skewed branches
- Loop unrolling only if the compiler didn't already and it measures faster

## Modern C++ Toolbox

Reach for these when they serve a measured goal, not for their own sake. Prefer the modern construct if the project's `-std` supports it; the annotation is the minimum standard.

- **`std::jthread` + `std::stop_token` (C++20)** — auto-joining workers with cooperative cancellation; prefer over raw `std::thread`
- **`std::popcount`, `std::countl_zero`, `std::has_single_bit`, etc. (C++20, `<bit>`)** — for bit manipulation and fingerprint/bitvector work
- **`std::span` (C++20), `std::mdspan` (C++23)** — non-owning contiguous/multidimensional views, zero-copy
- **`std::ranges` and views (C++20)** — expressive, often fusion-friendly pipelines
- **Concepts (C++20)** — clean template constraints
- **`std::execution` parallel algorithms (C++17)** — parallel `for_each`/`transform`/`reduce`
- **`std::simd` (C++26) / `std::experimental::simd` today** — portable vectorization
- **`constexpr` / `consteval`** — push work to compile time
- **`std::unique_ptr` with custom deleters, aligned allocators, arena/pool allocators** — keep the hot path allocation-free

## Data Layout and Memory Access

On modern CPUs this is typically the single biggest *micro*-level lever, because memory latency dominates:

- **Contiguous, sequential access** — prefer over pointer chasing
- **Struct-of-Arrays (SoA) vs. Array-of-Structs (AoS)** — when you touch one field across many elements, SoA improves cache and SIMD friendliness
  - Example: interleaved `xyz` triples → separate aligned `x[]`, `y[]`, `z[]`
- **Cache blocking / tiling** for matrix-like or all-pairs traversals
- **Alignment** — `alignas(64)`, aligned allocators so loads sit on cache-line and SIMD boundaries
- **Hoist allocations out of loops** — kill redundant allocations and copies in the hot path
- **`std::mdspan` (C++23)** — multidimensional views without copying

**Price the conversion:** A layout change isn't free. Transposing AoS→SoA or re-packing costs a full pass over the data, which can dwarf a single query. It pays off only when:
- The data is *stored* in the better layout to begin with, or
- Is reused/queried enough to amortize the one-time cost

Measure the conversion, not just the improved kernel, and say which regime you're in before recommending it.

## Parallelism

**Before adding threads:** check if the kernel is already memory-bandwidth-saturated. Adding threads to a bandwidth-bound kernel buys nothing.

**When there's real independent work:**
- `std::jthread` + `std::stop_token` (C++20) for task/worker parallelism
- `std::execution` parallel algorithms (C++17) for parallel `for_each`/`transform`/`reduce`
- OpenMP for straightforward loop parallelism

**Watch for:**
- **False sharing** — pad/align per-thread accumulators
- Scaling is capped by serial fraction (Amdahl's Law) and memory bandwidth

## Domain Example: Cheminformatics C++ (OpenEye/RDKit-Style)

The following patterns are characteristic of OpenEye Toolkits- and RDKit-style molecular/cheminformatics C++. Recognize them on sight:

### Iterating Atoms / Bonds / Conformers

Toolkit iterators (e.g., OpenEye's `OEIter`-style traversal) and per-element accessors are convenient but add indirection — virtual dispatch, pointer chasing — costly in tight numeric loops.

**For hot math:** extract what you need into contiguous arrays once (coordinates, charges, radii), compute on the arrays, then write back. This extract-to-SoA move is usually the single biggest win.

### Coordinate / Geometry Kernels

Pairwise distances, RMSD, superposition, clash/contact detection, neighbor search vectorize and cache-block well *if* coordinates are Struct-of-Arrays (aligned `x[]`, `y[]`, `z[]`) rather than interleaved triples.

**Hoist coordinate extraction out of nested loops** — never call a per-atom `GetCoords`-style accessor inside an O(N²) inner loop.

**Use squared distances to avoid `sqrt`**, and a spatial structure (cell list / k-d tree) to escape O(N²) neighbor searches.

### Fingerprints & Similarity (Tanimoto, Tversky)

This is bit-population work:
- Store fingerprints as arrays of `uint64_t`
- Use `std::popcount` (C++20, `<bit>`) / hardware POPCNT
- Compute Tanimoto as `popcount(A & B) / popcount(A | B)` word-by-word, not bit-by-bit
- Align the buffers; batches of comparisons parallelize trivially

### Substructure / SMARTS Matching and Graph Traversal

Branchy and pointer-heavy — a poor SIMD target. Wins come from:
- **Screening before matching** (fingerprint pre-filter)
- Ordering query atoms by rarity for early pruning
- Keeping the graph representation cache-friendly

Not from arithmetic tricks.

### Expensive Perception Recomputed by Accident

Ring perception (SSSR), aromaticity, symmetry, formal-charge assignment are costly — make sure they're computed once and cached, not re-triggered inside a loop. Where full SSSR isn't actually needed, a lighter graph query may do.

### Streaming Large Datasets

`oemolistream`/`oemolostream`-style I/O. At scale, parse/I/O can dominate compute:
- Reuse molecule objects and buffers across records (clear-and-refill rather than reallocate)
- Overlap I/O with compute
- Parallelize across molecules
