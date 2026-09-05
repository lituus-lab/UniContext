## SPDX-License-Identifier: Apache-2.0
import std/[json, os, strutils, unittest]
import UniContext/[context/builder, domain/types]

suite "Context compilation":
  test "publishes a parseable versioned context packet schema":
    let schemaPath = currentSourcePath.parentDir.parentDir / "fixtures" /
        "context" /
      "context-packet-v1.schema.json"
    let schema = parseFile(schemaPath)
    check schema["properties"]["context_version"]["const"].getInt == ContextPacketVersion
    check schema["required"].len == 9

  test "ranks authority and excludes drafts":
    let hits = @[
      SearchHit(noteId: "draft", status: "draft", authority: "maintainer",
          content: "draft"),
      SearchHit(noteId: "agent", status: "accepted", authority: "agent",
          content: "agent memory"),
      SearchHit(noteId: "test", path: "proof.md", heading: "Evidence",
        status: "accepted",
        authority: "test", updated: "2026-08-20", reviewAfter: "2026-08-22",
        content: "reproducible evidence")]
    let packet = buildContextPacket("verify", hits, 500, "2026-08-21")
    check packet.sources.len == 2
    check packet.sources[0].noteId == "test"
    check "draft" notin packet.rendered

  test "reports stale memory":
    let hits = @[SearchHit(noteId: "old", path: "old.md", heading: "Old",
      status: "accepted", authority: "maintainer", updated: "2025-01-01",
      reviewAfter: "2026-01-01", content: "old content")]
    let packet = buildContextPacket("resume", hits, 500, "2026-08-21")
    check packet.sources[0].stale
    check packet.warnings.len == 1

  test "renders bounded live repository state before stored memory":
    let git = GitState(root: "/tmp/example", branch: "feature/context",
      commit: "abc123",
      status: "## feature/context\n M src/example.nim", diff: "+change",
      available: true)
    let hits = @[SearchHit(noteId: "note", path: "note.md", heading: "Note",
      status: "accepted", authority: "maintainer", updated: "2026-08-21",
      content: "Stored memory")]
    let packet = buildContextPacket("inspect", hits, 500, "2026-08-21", git)
    check packet.git.available
    check "## Live repository" in packet.rendered
    check packet.rendered.find("## Live repository") < packet.rendered.find("## note")

  test "clips live repository output to the packet budget":
    let git = GitState(root: "/tmp/example", branch: "main", commit: "abc123",
      status: repeat("M file\n", 200), diff: repeat("+large diff\n", 500),
          available: true)
    let packet = buildContextPacket("inspect", @[], 500, "2026-08-21", git)
    check packet.git.truncated
    check packet.estimatedTokens <= packet.budgetTokens
    check "live Git output was truncated" in packet.warnings
    # The cap counts the marker too: appending it after slicing to the limit
    # put the pair back over the half-budget the code had just enforced.
    let gitLimit = max(128, max(256, 500 * 4) div 2)
    check packet.git.status.len + packet.git.diff.len <= gitLimit

  test "a long worktree path cannot overrun the packet on its own":
    # No status, no diff, nothing for `gitLimit` to trim: the path alone used
    # to be appended whatever it cost.
    let git = GitState(root: repeat("d", 600), branch: "main",
      commit: "abc123", available: true)
    let packet = buildContextPacket("inspect", @[], 128, "2026-08-21", git)
    check packet.estimatedTokens <= packet.budgetTokens
    check "live Git state did not fit the token budget" in packet.warnings

  test "clips an oversized task to the packet budget":
    let packet = buildContextPacket(repeat("large task ", 1000), @[], 128, "2026-08-21")
    check packet.estimatedTokens <= packet.budgetTokens
    check "task text was truncated" in packet.warnings
