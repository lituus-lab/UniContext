# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Budget"

nbText: """
# Budget

A packet is built to a **token budget**: between 128 and 32768 tokens. The
budget is not a suggestion — material that does not fit is left out, and the
packet says so rather than silently shrinking.

Budgeting works on characters, four per token, because that is what the
renderer can count without a tokenizer.
"""

nbCode:
  import std/strutils
  import UniContext

  proc note(id, content: string): SearchHit =
    SearchHit(noteId: id, path: id & ".md", heading: id, content: content,
      noteType: "decision", status: "accepted", visibility: "public",
      authority: "maintainer", updated: "2026-07-15")

  # Real notes, not one-liners: a budget only shows what it does when the
  # material is bigger than it.
  let hits = @[
    note("decision.storage", """Markdown files and their Git history are
      canonical. The SQLite database is a derived index: it may be deleted at
      any time and rebuilt from the notes, and nothing in it overrides the
      working tree. When the two disagree the notes win and the index is
      stale, never the other way round."""),
    note("decision.budget", """A packet is assembled to a token budget.
      Sections are considered in rank order and a section that does not fit is
      skipped rather than truncated, because half a note with its provenance
      line cut off is worse for a reader than no note at all."""),
    note("decision.repository", """Live repository state is read through a
      fixed set of read-only Git commands and capped at half the packet
      budget, so a noisy working tree can never crowd the notes out of the
      packet entirely.""")]

  for budget in [128, 256, 1024]:
    let packet = buildContextPacket("what fits?", hits, budget)
    echo budget, " tokens -> ", packet.sources.len, " of ", hits.len,
      " source(s), ", packet.estimatedTokens, " estimated"

nbText: """
Sections are considered in rank order, so a budget too small to hold everything
keeps the highest-ranked notes that fit -- a later, shorter one can still get
in after a longer one was passed over, and the packet warns how many did not.
A section that does not fit is skipped, not
truncated: half a note with its provenance line cut off is worse than no note.

## What warns

The task text itself is capped at a quarter of the budget. A task longer than
that is truncated, and the packet carries a warning saying so.
"""

nbCode:
  let long = "why " & repeat("and so on ", 40) & "?"
  let packet = buildContextPacket(long, hits, 128)
  for warning in packet.warnings:
    echo "warning: ", warning

nbText: """
## Live repository state

`memory_context` accepts a repository path. UniContext then runs a fixed
read-only set of `git` commands and puts the branch, the commit, a short status
and a bounded diff into the packet. The status and the diff are the parts with
no length of their own, and together they are capped at **half** the budget, so
live state cannot crowd the notes out. When it is cut, the packet says
that too.

This is the one place where UniContext reads something outside the knowledge
base, so it is also the one place worth a warning to the reader: a worktree's
status and diff go wherever the packet goes. Do not pass a private worktree to
a remote model unless sharing it is acceptable.

## The bounds are one value

128 and 32768 are stated in `domain/types`, and everything else reads them from
there — the builder's precondition, its error message, the C header's
`UNICONTEXT_BUDGET_MIN`/`_MAX`, and the Python binding's `BUDGET_MIN`/
`BUDGET_MAX`. `tests/test_version.nim` fails if the copies ever disagree.
"""

nbCode:
  echo "accepted budgets: ", MinBudgetTokens, " to ", MaxBudgetTokens
  for candidate in [0, MinBudgetTokens - 1, MinBudgetTokens, MaxBudgetTokens + 1]:
    var accepted = true
    try: discard buildContextPacket("q", hits, candidate)
    except ValueError: accepted = false
    echo "  ", candidate, "  ", (if accepted: "accepted" else: "refused")

nbSave
