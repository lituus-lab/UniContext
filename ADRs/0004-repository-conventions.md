<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: Repository conventions

- Status: Accepted
- Date: 2026-07-15
- Scope: UniContext's layout, naming and gates

## Layout

```text
UniContext.nimble             package + tasks
config.nims                   arch-conditional build flags
src/UniContext.nim            umbrella, re-exports the layers
src/UniContext/domain/        the types every other layer speaks in
src/UniContext/workspace/     the repository: manifest, Git state
src/UniContext/text/          Markdown parsing
src/UniContext/database/      the derived SQLite index (ADR-0005)
src/UniContext/context/       packet assembly under a token budget
src/UniContext/memory/        accepted-memory writer
src/UniContext/index/         the reprojection that fills the index
src/UniContext/protocol/      the MCP surface
src/UniContext/c_api.nim      C ABI
src/UniContext/cli.nim        the `unicontext` command
include/UniContext.h          hand-written C header
tests/ tests/c/               Nim + C ABI tests
examples/                     Nim + C demos
py/                           Cython binding + pytest
book/                         nimib book, code blocks run at build
ADRs/                         0001-0005
.github/workflows/ci.yml      3-OS Nim + C ABI + Python
```

The layer order is data, not prose: `vgraph.cfg` lists it and
`nimble checkVGraph` fails an import that climbs it.

## Naming

- Nim package/module: `UniContext` (PascalCase).
- C library: `libUniContext`. C header: `UniContext.h`.
- C symbol prefix `unicontext_`, the library's own name in lower case. Not a
  short token: a binary that links several engines holds them all in one
  namespace, and `uc_` has more than one plausible owner.
- Python distribution `lituus-unicontext`, import package `unicontext`.
- The command lives at `src/UniContext/cli.nim`, not `src/unicontext.nim`:
  the latter is the umbrella's path on a case-insensitive filesystem.

## Conventions

- NimContracts `{.contractual.}` + `require:`/`ensure:`/`body:`, compiled away
  under `-d:release`. The C ABI never raises -- it answers out-of-range input.
- A postcondition is cheaper than the body; it never re-derives the result.
- English comments, terse, describe what is done. No "deprecated".
- A value stated in more than one place (the version, the budget bounds) is
  checked by `tests/test_version.nim` rather than trusted.

## CI gates

Every task runs through `tools/gate.nim`: nimble exits 0 on a task whose `exec`
failed, so its exit code proves nothing and the task's own success marker is
what the gate reads.

- `testCi` + `testCiRelease` on ubuntu/macOS/Windows.
- `ctest`, `cexample` and `clib` on ubuntu/macOS/Windows.
- the Python matrix on ubuntu/macOS/Windows, 3.10 to 3.14.
- `lint`, `checkVGraph`, `docs` and `coverage` on ubuntu.
- `canary`, which must fail.
- `all-green` over all of them: the one check branch protection requires.
