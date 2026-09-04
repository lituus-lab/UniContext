## SPDX-License-Identifier: Apache-2.0
## Copyright 2026 lituus-lab
## Assemble a context packet from search hits: what the ranking promotes, what
## the status filter drops, and what the token budget leaves out.
import std/strutils
import UniContext

proc note(id, heading, authority, status, content: string;
    reviewAfter = ""): SearchHit =
  SearchHit(noteId: id, path: id & ".md", heading: heading, content: content,
    noteType: "decision", status: status, visibility: "public",
    authority: authority, updated: "2026-07-15", reviewAfter: reviewAfter)

when isMainModule:
  # `rank` is not an input: `ranked` derives it from authority and status, so
  # the order below is not the order the packet comes back in.
  let hits = @[
    note("note.agent", "Agent guess", "agent", "active",
         "Probably the index is authoritative."),
    note("decision.storage", "Storage", "maintainer", "accepted",
         "Markdown is canonical; the SQLite index is derived and rebuildable."),
    note("draft.retrieval", "Retrieval rewrite", "maintainer", "draft",
         "Half-written, and never meant to reach a model."),
    note("memory.budget", "Budget policy", "human", "accepted",
         "Assemble under a token budget; drop what does not fit.",
         reviewAfter = "2020-01-01")]

  for budget in [MinBudgetTokens, 1024]:
    let packet = buildContextPacket("how is context assembled?", hits, budget)
    echo "budget ", packet.budgetTokens, " tokens -> ", packet.sources.len,
      " of ", hits.len, " hit(s), ", packet.estimatedTokens, " estimated tokens"
    for source in packet.sources:
      echo "  ", source.noteId, " (", source.authority, ")",
        (if source.stale: " [stale]" else: "")
    for warning in packet.warnings:
      echo "  warning: ", warning
    echo ""

  echo "--- the packet a model is given, at 1024 tokens ---"
  echo buildContextPacket("how is context assembled?", hits,
      1024).rendered.strip
