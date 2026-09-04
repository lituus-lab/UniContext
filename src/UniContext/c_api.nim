## SPDX-License-Identifier: Apache-2.0
## Copyright 2026 lituus-lab
var VersionBytes: array[6, char] = ['1', '.', '0', '.', '0', '\0']
{.push exportc, cdecl, dynlib.}
proc unicontext_version(): cstring =
  let value = "1.0.0"
  copyMem(addr VersionBytes[0], value.cstring, VersionBytes.len)
  cast[cstring](addr VersionBytes[0])
proc unicontext_abi_version(): cint = 1
proc unicontext_valid_budget(tokens: cint): cint =
  if tokens >= 128 and tokens <= 32768: 1 else: 0
{.pop.}
