## SPDX-License-Identifier: Apache-2.0
import std/[algorithm, os, sets, strutils]
import UniContext/[database/store, domain/types, text/markdown]
import UniContext/workspace/manifest

type IndexReport* = object
  documents*: int
  sections*: int
  fingerprint*: string

const FnvOffset = 14_695_981_039_346_656_037'u64
const FnvPrime = 1_099_511_628_211'u64

proc mix(state: var uint64; value: string) =
  for character in value:
    state = state xor character.uint64
    state = state * FnvPrime
  state = state xor 0xff'u64
  state = state * FnvPrime

proc fingerprintValue(state: uint64): string = state.toHex(16).toLowerAscii

proc markdownFiles(root: string): seq[string] =
  for path in walkDirRec(root):
    let normalized = path.replace('\\', '/')
    if path.toLowerAscii.endsWith(".md") and "/.obsidian/" notin normalized and
        not normalized.endsWith("/.obsidian"):
      result.add(path)
  result.sort

proc visibilityLevel(value: string): int =
  case value
  of "private": 0
  of "team": 1
  of "public": 2
  else: -1

const MaxNoteBytes = 4 * 1024 * 1024
  ## Largest Markdown note the index will read. Checked against the file's
  ## size, not the string that was read: checking afterwards means the 4 GiB
  ## file is already in memory by the time it is refused.

proc readNote(path: string): string =
  if getFileSize(path) > MaxNoteBytes:
    raise newException(IOError, path & ": Markdown note exceeds 4 MiB")
  readFile(path)

proc addRoot(root, rootName, rootVisibility: string; database: Store;
    report: var IndexReport; seenIds: var HashSet[string];
        fingerprint: var uint64) =
  if not dirExists(root):
    raise newException(IOError, "missing root: " & root)
  const maxNotesPerRoot = 100_000
  let paths = markdownFiles(root)
  if paths.len > maxNotesPerRoot:
    raise newException(IOError, "root contains too many Markdown files")
  for path in paths:
    let content = readNote(path)
    fingerprint.mix(rootName)
    fingerprint.mix(rootVisibility)
    fingerprint.mix(path)
    fingerprint.mix(content)
    let note = parseMarkdown(content, path)
    let errors = note.validate
    if errors.len > 0:
      raise newException(MarkdownError, path & ": " & errors.join("; "))
    let noteId = note.frontmatter.get("id")
    if noteId in seenIds:
      raise newException(MarkdownError, path & ": duplicate note id: " & noteId)
    seenIds.incl(noteId)
    if visibilityLevel(note.frontmatter.get("visibility")) > visibilityLevel(rootVisibility):
      raise newException(MarkdownError, path & ": visibility exceeds the root visibility")
    database.add(note, rootName)
    inc report.documents
    report.sections += note.sections.len

proc rebuildIndex*(root, databasePath: string): IndexReport =
  var database = openStore(databasePath)
  defer: database.close
  database.initialize
  database.beginTransaction
  try:
    database.clear
    var seenIds = initHashSet[string]()
    var fingerprint = FnvOffset
    addRoot(root, "default", "public", database, result, seenIds, fingerprint)
    result.fingerprint = fingerprint.fingerprintValue
    database.setMetadata("corpus_fingerprint", result.fingerprint)
    database.commit
  except:
    database.rollback
    raise

proc rebuildIndex*(manifest: Manifest): IndexReport =
  var database = openStore(manifest.database)
  defer: database.close
  database.initialize
  database.beginTransaction
  try:
    database.clear
    var seenIds = initHashSet[string]()
    var fingerprint = FnvOffset
    for root in manifest.roots:
      addRoot(root.path, root.name, root.visibility, database, result, seenIds, fingerprint)
    result.fingerprint = fingerprint.fingerprintValue
    database.setMetadata("corpus_fingerprint", result.fingerprint)
    database.commit
  except:
    database.rollback
    raise

proc corpusFingerprint*(manifest: Manifest): string =
  var fingerprint = FnvOffset
  for root in manifest.roots:
    for path in markdownFiles(root.path):
      fingerprint.mix(root.name)
      fingerprint.mix(root.visibility)
      fingerprint.mix(path)
      fingerprint.mix(readNote(path))
  result = fingerprint.fingerprintValue

proc indexIsFresh*(manifest: Manifest): bool =
  if not fileExists(manifest.database): return false
  var database = openStore(manifest.database)
  defer: database.close
  database.initialize
  let indexed = database.getMetadata("corpus_fingerprint")
  indexed.len > 0 and indexed == manifest.corpusFingerprint
