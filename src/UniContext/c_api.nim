## SPDX-License-Identifier: Apache-2.0
## Copyright 2026 lituus-lab
##
## A deliberately narrow C ABI: the version pair every Uni* library exposes,
## plus the one predicate a C caller needs before it asks for a packet. A
## packet crosses the boundary as JSON through the MCP surface, not as a
## struct, so there is nothing else to marshal here.
import UniContext/domain/types

const UniContextVersionC: cstring = "1.0.0"
  ## Checked against the manifest, the header and the wheel by
  ## `tests/test_version.nim`.

{.push exportc, cdecl, dynlib.}

proc unicontext_version(): cstring =
  UniContextVersionC

proc unicontext_abi_version(): cint = 1

proc unicontext_valid_budget(tokens: cint): cint =
  ## Mirrors `buildContextPacket`'s precondition, from the same constants.
  if tokens >= cint(MinBudgetTokens) and tokens <= cint(MaxBudgetTokens): 1
  else: 0

{.pop.}
