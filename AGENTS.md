<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# AGENTS.md — UniContext

## Build & gates

```bash
nimble install -y
nim c --hints:off -o:build/unigate tools/gate.nim   # the failure gate, once

build/unigate testAll    # Nim debug + release + C ABI
build/unigate pyTest     # Cython + pytest (needs libUniContext.so)
build/unigate example
build/unigate cli        # the `unicontext` command, into build/
build/unigate coverage   # gcov + lcov -> coverage/ (needs lcov; linux/macOS)
build/unigate docs       # nimib book + API reference -> pages/ (needs nimib)
build/unigate canary     # must fail
```

Two sibling engines are declared in `UniContext.nimble` and fetched from
their own repositories: UniDatabase, reached only by `database/store`, and
UniMCP, reached only by `protocol/mcp_server`. `vgraph.cfg` records both the
layer order and that confinement; `checkVGraph` fails an import from anywhere
else, or a `requires` on a `Uni*` package that `[engines]` does not list.

The command lives at `src/UniContext/cli.nim`, never `src/unicontext.nim`:
on a case-insensitive filesystem that is the `src/UniContext.nim` umbrella.

Never `nimble <task>` bare where the answer matters: nimble 0.22 exits 0 even
when an `exec` inside the task failed. The gate reads the task's own success
marker instead, which is the only evidence it ran to its last line.

`nimble docs` needs a complete Nim distribution: `--project` builds `dochack`,
which Homebrew's `nim` omits (no `tools/`). choosenim and the CI action ship it.

CI: Nim, C ABI and Python each on ubuntu/macOS/Windows; lint, docs and
coverage on ubuntu; a canary job that must fail; `all-green` over all of them.

## Conventions

- English comments, terse, describe what is done. No "deprecated".
- NimContracts `{.contractual.}` + `require:`/`ensure:`/`body:`, compiled away
  under `-d:release`. C ABI never raises — it clamps out-of-range input.
- A postcondition is cheaper than the body: never re-derives the result by
  calling the function itself.
- C ABI: hand-written `include/UniContext.h` kept in sync with
  `src/UniContext/c_api.nim`; `tests/c` links the header against the lib.
  Built `--app:staticlib`/`--app:lib --noMain --mm:arc -d:release`.
- A change to `c_api.nim` is verified by `ctest`, `pyTest` and, where there
  is one, `wasmTest`: three linkages, three runtime bootstraps. A green
  `ctest` alone proved nothing the day the shared build lost its
  initializer and every registry answered with the sentinel.
- C symbols `unicontext_*` — the library's own name in lower case, not a
  short token: a binary linking several engines holds them in one namespace.
  Lib `libUniContext`; header `UniContext.h`.
- `book/index.nim` is nimib: its code blocks are compiled and run at docs build,
  so prose that outlives its API breaks the build. `py/notebooks/quickstart.ipynb`
  plays the same role for Python and renders natively on GitHub.
- End covered sources with a blank line. Nim maps a trailing statement one line
  past EOF; without that line lcov aborts on `range`/`unmapped`, and `coverage`
  keeps those fatal so the failure stays visible. It ignores exactly one error,
  `mismatch`, which lcov 2.0 raises on a NimContracts-generated destructor and
  lcov 2.5 does not — a compiler-generated symbol, not a line of the library.

## Scope

Compile readable, version-controlled knowledge sources into short, sourced
context packets: Markdown notes and their Git history are canonical, the SQLite
index is derived and rebuildable, and the MCP server is how an agent asks for a
packet. Apache-2.0, DCO.
