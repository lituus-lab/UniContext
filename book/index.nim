# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "UniContext"

nbText: """
# UniContext

A **context packet** is what a model is given: a task, the notes that bear on
it, and where each of them came from. UniContext compiles one from Markdown
notes under a token budget.

Markdown and its Git history are canonical. The SQLite index is derived: delete
it and it rebuilds from the notes. Nothing in the index overrides the working
tree.

## Installing

```bash
nimble install https://github.com/lituus-lab/UniContext    # Nim
pip install lituus-unicontext                              # Python
```

## The smallest packet

A search hit is a note the index found. Give a few to `buildContextPacket`
with a task and a budget, and it returns the packet.
"""

nbCode:
  import UniContext

  proc note(id, heading, authority, status, content: string): SearchHit =
    SearchHit(noteId: id, path: id & ".md", heading: heading, content: content,
      noteType: "decision", status: status, visibility: "public",
      authority: authority, updated: "2026-07-15")

  let hits = @[
    note("decision.storage", "Storage", "maintainer", "accepted",
         "Markdown is canonical; the SQLite index is derived and rebuildable."),
    note("memory.budget", "Budget policy", "human", "accepted",
         "Assemble under a token budget; drop what does not fit.")]

  let packet = buildContextPacket("how is context assembled?", hits, 1024)
  echo packet.rendered

nbText: """
Two things in that output are worth naming.

The **Source** line under each heading is the packet's provenance: the file it
came from, who stands behind it, and when it was last updated. A packet without
it is a wall of text a reader cannot check.

The packet also carries what it did not print. `sources` lists what got in, and
`estimatedTokens` says how much of the budget was used.
"""

nbCode:
  echo packet.sources.len, " source(s), ", packet.estimatedTokens,
    " of ", packet.budgetTokens, " tokens"
  for source in packet.sources:
    echo "  ", source.noteId, " (", source.authority, ")"

nbText: """
The two chapters that follow are about the two ways a note fails to reach the
model: it is **not allowed in** — the next chapter — or it **did not fit** —
the one after that.
"""

nbSave
