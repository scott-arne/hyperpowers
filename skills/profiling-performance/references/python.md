# Python Language Pack for `hyperpowers:profiling-performance`

This reference provides Python-specific profilers, GIL-awareness, vectorization strategies, and allocation/interpreter-level optimization patterns. It supplements the agnostic `profiling-performance` skill spine — do not duplicate the general workflow here; reference it instead.

## Profiling Tools

**Sampling profilers (lower overhead, no code changes):**
- **`py-spy`** (recommended for production/long-running processes) — sampling profiler, no instrumentation, works on running processes
  - `py-spy top --pid <pid>` — live top-like view
  - `py-spy record -o profile.svg --pid <pid>` — flamegraph
  - Can attach to running Python processes without restarting
- **`scalene`** — CPU + memory + GPU profiler, sampling-based
  - Shows per-line CPU time, memory allocations, GPU usage
  - `scalene script.py`
  - Identifies native vs. Python time, allocation sites

**Deterministic/instrumentation profilers (higher overhead, precise call counts):**
- **`cProfile`** (stdlib) — deterministic profiler, function-level call counts and cumulative time
  - `python -m cProfile -o output.prof script.py`
  - Analyze with `pstats`: `python -m pstats output.prof`
  - Good for understanding call patterns, but overhead affects absolute timings
- **`line_profiler`** — line-by-line timing (instrumentation)
  - Decorate functions with `@profile`, run `kernprof -lv script.py`
  - Shows time per line; use for hot-function deep dives
- **`memory_profiler`** — line-by-line memory usage (instrumentation)
  - Decorate with `@profile`, run `python -m memory_profiler script.py`
  - Identifies allocation-heavy lines

**Microbenchmarking:**
- **`timeit`** (stdlib) — for micro-level comparisons of small code snippets
  - `python -m timeit -s "setup" "code"`
  - Handles warmup, iteration; good for comparing alternatives
- **`pytest-benchmark`** — for repeatable in-test benchmarks with statistical analysis

**Choosing:**
- Start with **`py-spy`** or **`scalene`** for broad profiling (sampling, low overhead)
- Drop to **`cProfile`** when you need precise call counts
- Use **`line_profiler`** / **`memory_profiler`** for targeted deep dives into a known hot function

## The GIL (Global Interpreter Lock)

The GIL is CPython's global lock that prevents true parallel execution of Python bytecode.

**Key rules:**
1. **CPU-bound pure-Python work does NOT scale on threads** — the GIL serializes bytecode execution, so adding threads to a CPU-bound task buys nothing (or makes it worse due to context-switch overhead).
2. **I/O-bound work DOES benefit from threads or `asyncio`** — I/O operations release the GIL, so threads can overlap I/O waits.
3. **Native extensions and NumPy release the GIL** — C extensions that call `Py_BEGIN_ALLOW_THREADS` release the GIL during compute; NumPy, SciPy, Cython with `nogil`, and well-written C extensions fall into this category. Multi-threaded NumPy can scale on multiple cores.

**Workarounds for CPU-bound parallelism:**
- **`multiprocessing`** — separate Python processes, each with its own GIL
  - True parallelism for CPU-bound work
  - Higher memory overhead (separate interpreter per process)
  - Use `Pool`, `ProcessPoolExecutor` for task parallelism
- **Native extensions / Cython with `nogil`** — move hot loops into compiled code that releases the GIL
- **Numba with `@jit(nogil=True)`** — JIT-compiled functions that release the GIL
- **Alternative interpreters:** PyPy (JIT, still has GIL), free-threaded CPython builds (3.13+, experimental, opt-in `--disable-gil` builds) — the free-threaded build is real but still experimental as of early 2026; do not assume it is the default or widely deployed yet.

**Identifying GIL-bound code:**
- Profile shows CPU at 100% but adding threads doesn't help
- Work is pure Python (not NumPy/C extensions)
- Hot loop is compute-heavy, not I/O

## Vectorize / Push Work Into Native Code

**Core strategy:** avoid per-element Python-level loops on large data; push the loop into compiled code.

**High-leverage moves:**
1. **Use NumPy/pandas vectorized operations** instead of explicit loops
   - `arr.sum()` instead of `sum(arr)`
   - `arr * 2` instead of `[x * 2 for x in arr]`
   - NumPy operations are C-level loops, 10-100× faster
2. **Use built-in `map`, `filter`, comprehensions** over manual loops (marginal, but still better)
3. **Drop into compiled extensions for hot kernels:**
   - **Numba** — JIT-compile Python functions with `@jit` / `@njit`
     - Minimal code changes, works on subset of Python + NumPy
     - Can release GIL with `@jit(nogil=True)`
   - **Cython** — statically compiled Python-like language
     - More invasive (separate `.pyx` files), more control
     - Can release GIL, call C libraries, type-annotate for speed
   - **Raw C extension / ctypes / cffi** — for maximum control

**Example — avoid this:**
```python
result = []
for x in data:
    result.append(expensive_function(x))
```

**Better (if `expensive_function` is vectorizable):**
```python
result = numpy_vectorized_function(data)  # or use Numba @vectorize
```

**Or parallelize with `multiprocessing` if truly independent:**
```python
from multiprocessing import Pool
with Pool() as p:
    result = p.map(expensive_function, data)
```

## Allocation & Object Overhead

Python allocates on every object creation; the interpreter pays for attribute access, boxing, and temporary intermediate objects.

**Common sources of allocation pressure:**
- **List/dict comprehensions with large intermediate results** — can allocate heavily
- **Repeated string concatenation** — `s += x` in a loop reallocates each time; use `"".join(parts)` instead
- **Temporary NumPy arrays** — chain operations carefully to avoid intermediate copies
- **Per-iteration object creation in hot loops** — hoist allocations out

**Mitigation strategies:**
1. **Generators instead of lists** when you don't need the full collection in memory at once
   - `(x for x in range(n))` vs. `[x for x in range(n)]`
2. **`__slots__`** on classes with many instances — eliminates per-instance `__dict__`, reduces memory footprint
   ```python
   class Point:
       __slots__ = ('x', 'y')
   ```
3. **Reuse buffers / pre-allocate** — for NumPy, allocate once and fill in place
   ```python
   result = np.empty(n)  # pre-allocate
   compute_into(result)  # fill in place
   ```
4. **Avoid needless copies** — use views (`arr[::2]` is a view, `arr.copy()` is a copy)
5. **`array.array`, `numpy.ndarray`, `memoryview`** for large homogeneous collections instead of lists of scalars

## Interpreter-Loop Hot Paths

The CPython bytecode interpreter itself has overhead. Small changes can reduce interpreter work:

**Attribute and global lookup caching:**
- **Hoist attribute lookups out of loops**
  ```python
  # Slow:
  for x in data:
      result.append(math.sqrt(x))  # lookups `math.sqrt` every iteration
  
  # Faster:
  sqrt = math.sqrt
  for x in data:
      result.append(sqrt(x))
  ```
- **Hoist global lookups** similarly

**Prefer built-ins and comprehensions:**
- Built-in functions (`sum`, `max`, `min`, `map`, `filter`) are implemented in C and faster than equivalent Python loops
- List/dict/set comprehensions are faster than manual loop+append

**Avoid recomputation:**
- Hoist loop-invariant expressions out of loops
- Cache results of expensive pure functions

**These are micro-optimizations** — measure first. They matter most in tight, frequently-called loops.

## Async / Event Loop (I/O-Bound Concurrency)

**`asyncio` is for I/O-bound concurrency, NOT CPU-bound parallelism.**

**Key principles:**
1. **Concurrency ≠ parallelism** — `asyncio` multiplexes I/O on a single thread; CPU-bound work in an `async` function still blocks the event loop.
2. **Don't block the event loop** — synchronous I/O, CPU-heavy compute, or blocking calls freeze the entire event loop. Offload blocking work to a thread pool (`loop.run_in_executor`) or process pool.
3. **Use `asyncio` when:**
   - You have many concurrent I/O operations (network, disk)
   - Low per-connection resource cost vs. threads
   - The bottleneck is I/O latency, not CPU
4. **Profile async code with `py-spy`** (it understands async stacks) or specialized async profilers

**Async is not a performance silver bullet** — adding `async`/`await` to CPU-bound code makes it slower (event-loop overhead with no I/O parallelism benefit).

## Example: Identifying and Fixing a Slow Python Function

**Scenario:** a function processing a large list is slow.

1. **Profile with `py-spy` or `scalene`** — identify if it's CPU-bound, allocation-bound, or spending time in native code.
2. **Check for vectorization opportunities** — is there a per-element loop you can replace with NumPy?
3. **Check for GIL-bound parallelism** — if CPU-bound and pure Python, consider `multiprocessing` or Numba.
4. **Check for allocation hotspots** — use `scalene` or `memory_profiler` to find allocation-heavy lines; consider generators, pre-allocation, or `__slots__`.
5. **Check for interpreter overhead** — hoist attribute/global lookups, use built-ins.

**Typical win stack (descending order of impact):**
1. Algorithmic change (O(n²) → O(n log n))
2. Vectorize with NumPy (10-100× for numeric loops)
3. Offload to native code (Numba, Cython)
4. Parallelize with `multiprocessing` (if GIL-bound)
5. Reduce allocations (generators, reuse, `__slots__`)
6. Interpreter micro-opts (hoist lookups, use built-ins)

## Common Python Performance Anti-Patterns

**STOP if you see:**
- **Nested Python loops over large NumPy arrays** — vectorize or use Numba
- **`for i in range(len(arr)): arr[i] = ...`** — use vectorized assignment or `np.vectorize` / Numba
- **String concatenation in a loop** — use `"".join()`
- **List when a generator would do** — wasteful allocation
- **Calling expensive pure function repeatedly with same args** — memoize (`functools.lru_cache`)
- **Threads for CPU-bound work** — won't scale due to GIL; use `multiprocessing`
- **Blocking I/O in `asyncio`** — blocks the event loop; use `run_in_executor` or async libraries

## Tooling Notes

**Install profilers:**
```bash
pip install py-spy scalene line-profiler memory-profiler
```

**Quick py-spy command reference:**
```bash
py-spy top --pid <pid>                    # live top view
py-spy record -o profile.svg --pid <pid>  # flamegraph
py-spy record -o profile.speedscope --format speedscope --pid <pid>  # speedscope format
```

**Quick scalene:**
```bash
scalene script.py                         # CPU + memory + GPU
scalene --html --outfile report.html script.py  # HTML report
```

**Interpreting cProfile output:**
- `tottime` — time in function excluding subcalls (exclusive time)
- `cumtime` — time in function including subcalls (inclusive time)
- Sort by `tottime` to find CPU hotspots: `python -m pstats output.prof` then `sort tottime` then `stats 20`
