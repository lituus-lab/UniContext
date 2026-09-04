# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## The version and the budget range, stated in six places, checked to agree.
##
## Nimble refuses anything but a string literal for `version`, so the manifest
## cannot import a shared constant and no amount of arranging makes one file
## the source the others derive from. What is achievable is proof: this test
## reads every copy and fails when one drifts, which is what a release needs
## before it can claim manifest = header = wheel = tag.
import std/[unittest, os, strutils]
import UniContext

const Root = currentSourcePath().parentDir.parentDir

proc valueOf(path, key, opener, closer: string): string =
  ## The first `key … opener VALUE closer` on one line of the file; an empty
  ## `closer` reads to the end of the line. Deliberately crude: a parser per
  ## format would be more code than the thing it checks.
  for line in readFile(Root / path).splitLines:
    let at = line.find(key)
    if at < 0: continue
    let opens = line.find(opener, at + key.len)
    if opens < 0: continue
    let value = line[opens + opener.len .. ^1]
    if closer.len == 0: return value.strip
    let closes = value.find(closer)
    if closes < 0: continue
    return value[0 ..< closes]
  ""

suite "one version, six copies":
  let manifest = valueOf("UniContext.nimble", "version", "\"", "\"")

  test "the manifest states one":
    check manifest.len > 0
    check manifest.count('.') == 2

  test "the Nim constant agrees":
    check UniContextVersion == manifest

  test "the C header agrees, macros and string alike":
    let parts = manifest.split('.')
    check valueOf("include/UniContext.h", "UNICONTEXT_VERSION_MAJOR", " ",
        "") == parts[0]
    check valueOf("include/UniContext.h", "UNICONTEXT_VERSION_MINOR", " ",
        "") == parts[1]
    check valueOf("include/UniContext.h", "UNICONTEXT_VERSION_PATCH", " ",
        "") == parts[2]
    check valueOf("include/UniContext.h", "define UNICONTEXT_VERSION ", "\"",
        "\"") == manifest

  test "the C ABI reports it":
    # Read from the source rather than called: this suite links no C library.
    check valueOf("src/UniContext/c_api.nim", "UniContextVersionC", "\"",
        "\"") == manifest

  test "the Python distribution agrees":
    check valueOf("py/pyproject.toml", "version", "\"", "\"") == manifest

  test "the Python test expects it":
    check valueOf("py/tests/test_unicontext.py", "version()", "\"",
        "\"") == manifest

suite "one budget range, three copies":
  # A C consumer sizes its own checks against the macros, so the header
  # states the bounds as literals as well as answering for them.
  test "the C macros agree with the Nim constants":
    check valueOf("include/UniContext.h", "UNICONTEXT_BUDGET_MIN", " ", "") ==
      $MinBudgetTokens
    check valueOf("include/UniContext.h", "UNICONTEXT_BUDGET_MAX", " ", "") ==
      $MaxBudgetTokens

  test "the builder enforces exactly that range":
    let hits = @[SearchHit(noteId: "n", rank: 1)]
    expect ValueError:
      discard buildContextPacket("q", hits, MinBudgetTokens - 1)
    expect ValueError:
      discard buildContextPacket("q", hits, MaxBudgetTokens + 1)
    check buildContextPacket("q", hits, MinBudgetTokens).budgetTokens ==
      MinBudgetTokens
    check buildContextPacket("q", hits, MaxBudgetTokens).budgetTokens ==
      MaxBudgetTokens
