## SPDX-License-Identifier: Apache-2.0
import std/[algorithm, strformat, times]
import contracts
import UniContext/domain/types

proc authorityWeight(authority: string): int =
  case authority
  of "test": 100
  of "code": 95
  of "maintainer": 90
  of "human": 75
  of "external": 50
  of "agent": 25
  else: 0

proc statusWeight(status: string): int =
  case status
  of "accepted": 30
  of "active": 25
  else: 0

proc allowed(hit: SearchHit): bool =
  hit.status notin ["draft", "proposed", "superseded", "archived"]

proc isStale(reviewAfter, today: string): bool =
  reviewAfter.len > 0 and reviewAfter < today

proc isOrdered(hits: seq[SearchHit]): bool =
  ## The order `ranked` promises: rank descending, then most recently updated,
  ## then note id. A scan, so the postcondition stays cheaper than the sort it
  ## checks and never re-derives it by ranking again.
  for i in 1 ..< hits.len:
    let previous = hits[i - 1]
    let current = hits[i]
    if previous.rank < current.rank: return false
    if previous.rank == current.rank:
      if previous.updated < current.updated: return false
      if previous.updated == current.updated and previous.noteId >
          current.noteId:
        return false
  true

proc ranked*(hits: seq[SearchHit]; today = now().format("yyyy-MM-dd")): seq[SearchHit]
    {.contractual.} =
  ## Drop what a model must not be given, score what is left, and order it.
  ## `rank` is derived here from authority and status: whatever the caller put
  ## in that field is overwritten.
  ensure:
    result.len <= hits.len
    result.isOrdered
  body:
    for candidate in hits:
      if candidate.allowed:
        var hit = candidate
        hit.rank = authorityWeight(hit.authority) + statusWeight(hit.status)
        hit.stale = isStale(hit.reviewAfter, today)
        if hit.stale: hit.rank -= 20
        result.add(hit)
    result.sort(proc(a, b: SearchHit): int =
      result = cmp(b.rank, a.rank)
      if result == 0: result = cmp(b.updated, a.updated)
      if result == 0: result = cmp(a.noteId, b.noteId))

proc buildContextPacket*(query: string; hits: seq[SearchHit]; budgetTokens: int;
    today = now().format("yyyy-MM-dd"); git = GitState();
    initialWarnings: seq[string] = @[]): ContextPacket =
  if budgetTokens < MinBudgetTokens or budgetTokens > MaxBudgetTokens:
    raise newException(ValueError, "budget_tokens must be between " &
      $MinBudgetTokens & " and " & $MaxBudgetTokens)
  if query.len == 0:
    raise newException(ValueError, "query must not be empty")
  result.version = ContextPacketVersion
  result.query = query
  result.budgetTokens = budgetTokens
  let maxChars = max(256, budgetTokens * 4)
  let taskLimit = max(64, maxChars div 4)
  var renderedQuery = query
  if renderedQuery.len > taskLimit:
    renderedQuery = renderedQuery[0 ..< taskLimit] & "\n[task truncated by UniContext]"
    result.warnings.add("task text was truncated")
  result.rendered = "# Context packet v1\n\n## Task\n\n" & renderedQuery & "\n"
  for warning in initialWarnings:
    result.warnings.add(warning)
    let warningBlock = "\n> WARNING: " & warning & "\n"
    if result.rendered.len + warningBlock.len <= maxChars:
      result.rendered.add(warningBlock)
  result.git = git
  let gitLimit = max(128, maxChars div 2)
  if result.git.status.len + result.git.diff.len > gitLimit:
    result.git.truncated = true
    let statusLimit = min(result.git.status.len, gitLimit div 3)
    result.git.status = result.git.status[0 ..< statusLimit]
    let diffLimit = max(0, gitLimit - result.git.status.len)
    if result.git.diff.len > diffLimit:
      # The marker is part of what the budget pays for: appended after slicing
      # to the limit, it put the packet over the cap it had just enforced.
      const marker = "\n[output truncated by UniContext]"
      let room = max(0, diffLimit - marker.len)
      result.git.diff = result.git.diff[0 ..< room] & marker
  if result.git.available:
    result.rendered.add("\n## Live repository\n\n")
    result.rendered.add("- root: `" & result.git.root & "`\n")
    result.rendered.add("- branch: `" & result.git.branch & "`\n")
    result.rendered.add("- commit: `" & result.git.commit & "`\n")
    if result.git.status.len > 0:
      result.rendered.add("\n### Git status\n\n```text\n" & result.git.status & "\n```\n")
    if result.git.diff.len > 0:
      result.rendered.add("\n### Working-tree diff\n\n```diff\n" &
          result.git.diff & "\n```\n")
    if result.git.truncated:
      result.warnings.add("live Git output was truncated")
  elif result.git.warning.len > 0:
    result.warnings.add(result.git.warning)
  # Counted, then reported once: a packet that quietly holds less than the
  # caller's material gives a reader no way to know something was left out.
  var omitted = 0
  for hit in ranked(hits, today):
    var sectionBlock = &"\n## {hit.noteId} — {hit.heading}\n\n" &
      &"Source: `{hit.path}` · authority: `{hit.authority}` · updated: `{hit.updated}`\n\n" &
      hit.content & "\n"
    if hit.stale:
      sectionBlock.add("\n> WARNING: memory requires review (review_after " &
        hit.reviewAfter & ")\n")
    if result.rendered.len + sectionBlock.len > maxChars:
      inc omitted
      continue
    result.rendered.add(sectionBlock)
    result.sources.add(ContextSource(noteId: hit.noteId, path: hit.path,
      heading: hit.heading, authority: hit.authority, updated: hit.updated,
      stale: hit.stale))
    if hit.stale:
      result.warnings.add("memory requires review: " & hit.noteId &
          " (review_after " & hit.reviewAfter & ")")
  if omitted > 0:
    result.warnings.add($omitted & " source(s) did not fit the token budget")
  result.estimatedTokens = (result.rendered.len + 3) div 4
  if result.sources.len == 0:
    result.warnings.add("no eligible source fits within the budget")
