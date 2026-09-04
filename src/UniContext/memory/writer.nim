## SPDX-License-Identifier: Apache-2.0
import std/[json, os, strutils, times]
import UniContext/workspace/manifest

type MemoryWriteError* = object of IOError

proc validateIdentifier(value, label: string) =
  if value.len < 3 or value.len > 120:
    raise newException(MemoryWriteError, label & " must contain between 3 and 120 characters")
  for character in value:
    if character notin {'a'..'z', 'A'..'Z', '0'..'9', '.', '_', '-'}:
      raise newException(MemoryWriteError, label & " contains a forbidden character")

proc yaml(value: string): string =
  $(%value)

proc writeNew(path, content: string) =
  if fileExists(path) or dirExists(path) or symlinkExists(path):
    raise newException(MemoryWriteError,
        "append-only write refused because target exists: " & path)
  let parent = path.parentDir
  if not dirExists(parent): createDir(parent)
  writeFile(path, content)

proc requireDirectory(manifest: Manifest; path, label: string): string =
  if path.len == 0:
    raise newException(MemoryWriteError, label & " is not configured in the manifest")
  result = manifest.secureWriteDirectory(path)
  if not dirExists(result): createDir(result)
  result = manifest.secureWriteDirectory(result)

proc today(): string = now().format("yyyy-MM-dd")

proc propose*(manifest: Manifest; noteId, title, summary: string;
    evidence: seq[string]): string =
  validateIdentifier(noteId, "id")
  if not noteId.startsWith("proposal."):
    raise newException(MemoryWriteError, "a proposal id must start with proposal.")
  if title.strip.len == 0 or summary.strip.len == 0:
    raise newException(MemoryWriteError, "title and summary are required")
  let directory = requireDirectory(manifest, manifest.proposalDir, "proposal_dir")
  result = directory / (noteId & ".md")
  var body = "---\n" &
    "id: " & yaml(noteId) & "\n" &
    "type: proposal\nstatus: proposed\nvisibility: private\nauthority: agent\n" &
    "created: " & today() & "\nupdated: " & today() & "\n---\n" &
    "# " & title.strip & "\n\n## Summary\n\n" & summary.strip & "\n"
  if evidence.len > 0:
    body.add("\n## Proposed evidence\n")
    for item in evidence:
      body.add("\n- " & item.replace("\n", " ").strip)
    body.add('\n')
  writeNew(result, body)

proc sessionDirectory(manifest: Manifest; sessionId: string): string =
  validateIdentifier(sessionId, "session_id")
  let base = requireDirectory(manifest, manifest.sessionDir, "session_dir")
  result = manifest.secureWriteDirectory(base / sessionId)

proc sessionStart*(manifest: Manifest; sessionId, project,
    objective: string): string =
  if objective.strip.len == 0:
    raise newException(MemoryWriteError, "objective is required")
  let directory = sessionDirectory(manifest, sessionId)
  result = directory / "000-start.md"
  let noteId = "session." & sessionId & ".start"
  let body = "---\n" &
    "id: " & yaml(noteId) & "\ntype: session\nstatus: active\nvisibility: private\n" &
    "authority: agent\ncreated: " & today() & "\nupdated: " & today() & "\n" &
    "project: " & yaml(project) & "\n---\n# Session start\n\n## Objective\n\n" &
    objective.strip & "\n"
  writeNew(result, body)

proc sessionUpdate*(manifest: Manifest; sessionId, eventId,
    summary: string): string =
  validateIdentifier(eventId, "event_id")
  if summary.strip.len == 0:
    raise newException(MemoryWriteError, "summary is required")
  let directory = sessionDirectory(manifest, sessionId)
  if not fileExists(directory / "000-start.md"):
    raise newException(MemoryWriteError, "unknown session: " & sessionId)
  result = directory / ("500-" & eventId & ".md")
  let noteId = "session." & sessionId & "." & eventId
  let body = "---\nid: " & yaml(noteId) &
    "\ntype: session\nstatus: active\nvisibility: private\nauthority: agent\n" &
    "created: " & today() & "\nupdated: " & today() &
        "\n---\n# Session update\n\n" &
    summary.strip & "\n"
  writeNew(result, body)

proc sessionClose*(manifest: Manifest; sessionId, outcome,
    nextAction: string): string =
  if outcome.strip.len == 0:
    raise newException(MemoryWriteError, "outcome is required")
  let directory = sessionDirectory(manifest, sessionId)
  if not fileExists(directory / "000-start.md"):
    raise newException(MemoryWriteError, "unknown session: " & sessionId)
  result = directory / "999-close.md"
  let noteId = "session." & sessionId & ".close"
  var body = "---\nid: " & yaml(noteId) &
    "\ntype: session\nstatus: archived\nvisibility: private\nauthority: agent\n" &
    "created: " & today() & "\nupdated: " & today() &
        "\n---\n# Session close\n\n" &
    "## Outcome\n\n" & outcome.strip & "\n"
  if nextAction.strip.len > 0:
    body.add("\n## Next action\n\n" & nextAction.strip & "\n")
  writeNew(result, body)
