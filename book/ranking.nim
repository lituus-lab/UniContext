# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Ranking"

nbText: """
# Ranking

`ranked` decides two things: which hits a model may see at all, and in what
order. Both are derived from the note's own metadata, never from the caller.

## What is not allowed in

A note whose status is `draft`, `proposed`, `superseded` or `archived` is
dropped. Half-written and withdrawn material is not something to rank lower —
it is something a model must not be given.
"""

nbCode:
  import UniContext

  proc note(id, authority, status: string; reviewAfter = ""): SearchHit =
    SearchHit(noteId: id, path: id & ".md", heading: id, content: "…",
      noteType: "decision", status: status, visibility: "public",
      authority: authority, updated: "2026-07-15", reviewAfter: reviewAfter)

  let hits = @[
    note("draft.retrieval", "maintainer", "draft"),
    note("old.approach", "maintainer", "superseded"),
    note("decision.storage", "maintainer", "accepted")]

  echo hits.len, " hits in, ", ranked(hits).len, " out"
  for hit in ranked(hits): echo "  ", hit.noteId

nbText: """
## The order

What survives is scored by **authority** — who stands behind the note — plus a
smaller weight for **status**. The caller's `rank` field is not read; it is
overwritten.

| Authority | Weight | | Status | Weight |
|---|---|---|---|---|
| `test` | 100 | | `accepted` | 30 |
| `code` | 95 | | `active` | 25 |
| `maintainer` | 90 | | | |
| `human` | 75 | | | |
| `external` | 50 | | | |
| `agent` | 25 | | | |

A test or the code itself outranks a person, and a person outranks an agent's
own note. That ordering is the point: what the repository can prove beats what
somebody remembered.
"""

nbCode:
  let voices = @[
    note("agent.guess", "agent", "active"),
    note("test.fixture", "test", "accepted"),
    note("human.decision", "human", "accepted")]

  for hit in ranked(voices):
    echo hit.rank, "  ", hit.noteId

nbText: """
## Freshness

A note may carry `review_after`. Once that date has passed the note is **stale**:
it still reaches the model, but 20 points lighter and with a warning attached,
so a reader can see that nobody has confirmed it lately.
"""

nbCode:
  let aging = @[
    note("memory.old", "maintainer", "accepted", reviewAfter = "2020-01-01"),
    note("memory.fresh", "maintainer", "accepted")]

  for hit in ranked(aging, today = "2026-07-15"):
    echo hit.rank, "  ", hit.noteId, (if hit.stale: "  [stale]" else: "")

nbText: """
## The order is a promise, and it is checked

Three tie-breaks are easy to write and easy to break later, so `ranked` states
them as a postcondition rather than trusting its own comparator:

```nim
ensure:
  result.len <= hits.len
  result.isOrdered
```

`isOrdered` is a scan, so the check costs less than the sort it guards and
never re-ranks to find the answer. NimContracts compiles it away under
`-d:release`; in a debug build, inverting the comparator stops the test suite
with a `PostConditionDefect` instead of publishing a subtly wrong packet.
"""

nbSave
