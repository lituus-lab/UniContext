# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[os, osproc, strutils]
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Surfaces"

const Root = currentSourcePath().parentDir.parentDir

proc run(command: string): string =
  ## Run a command from the repository root and return its output. Used so the
  ## C and Python results on this page are produced rather than transcribed.
  ##
  ## A non-zero exit stops the book. Returning the failure as text instead
  ## would publish a page whose "output" is a traceback, from a build that
  ## reported success -- which is exactly what happened before this raised.
  let (output, code) = execCmdEx("cd " & Root.quoteShell & " && " & command)
  result = output.strip
  if code != 0:
    raise newException(OSError,
      "book: `" & command & "` exited " & $code & "\n" & result)

nbText: """
# Surfaces

UniContext reaches four kinds of caller, and they are not given the same thing.

| Surface | What it gets | Out of range |
|---|---|---|
| Nim | the whole library | `buildContextPacket` raises `ValueError` |
| MCP | JSON-RPC tools over stdio | a JSON-RPC error to the client |
| C | version, ABI generation, budget predicate | **answered**, never raised |
| Python | the C ABI through Cython | `valid_budget` returns `False` |

The asymmetry is deliberate. A packet is a document, not a struct: marshalling
it through C would mean inventing an ownership convention for every string in
it, so the packet crosses that boundary as JSON through the MCP surface
instead. What the C ABI does offer is the one question a C caller must answer
before it asks for a packet at all — is this budget acceptable?

## The C ABI answers, it does not raise

A Nim exception unwinding into C is undefined behaviour, so
`unicontext_valid_budget` answers for every `int` a caller can pass, including
the ones outside the domain.
"""

nbCode:
  echo readFile(Root / "book" / "surfaces_demo.c")

nbText: """
Built against the static library and run:
"""

nbCode:
  discard run("nimble clibStatic")
  echo run("cc -Iinclude -O2 -Wall -Wextra -std=c11 " &
    "-o build/surfaces_demo book/surfaces_demo.c libUniContext.a && " &
    "./build/surfaces_demo")

nbText: """
`1` for the smallest legal budget, `0` for zero and for one past the largest.
No exit code, no error state to check: the answer *is* the return value.

## The bounds are the header's

Both the C demo above and the Python binding below read `UNICONTEXT_BUDGET_MIN`
and `UNICONTEXT_BUDGET_MAX` from `include/UniContext.h`. Neither restates the
numbers, so neither can drift from what the library enforces.

## Python

The wheel bundles the shared library, so a Python caller installs one thing.
"""

nbCode:
  # The extension is built in place by `nimble buildCython`, so the chapter
  # imports it from py/ rather than requiring the wheel to be installed.
  discard run("nimble buildCython")
  echo run("cd py && python3 -c \"import unicontext; " &
    "print(unicontext.version(), unicontext.abi_version()); " &
    "print(unicontext.BUDGET_MIN, unicontext.BUDGET_MAX); " &
    "print(unicontext.valid_budget(0), unicontext.valid_budget(4096))\"")

nbText: """
## The command

For a knowledge base on disk, the command is the shortest path: it indexes,
searches, compiles a packet, and serves the MCP tools.

```bash
unicontext index   --manifest /absolute/path/to/unicontext.toml
unicontext context --manifest /absolute/path/to/unicontext.toml \
  --query "memory authority" --budget 4000
unicontext serve   --manifest /absolute/path/to/unicontext.toml
```

`serve` is the surface an agent uses. `docs/integration.md` has the client
declaration and the clients it has been checked against.
"""

nbSave
