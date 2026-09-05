## SPDX-License-Identifier: Apache-2.0
import std/[os, strutils]

type
  ManifestError* = object of ValueError
  RootSpec* = object
    name*: string
    path*: string
    visibility*: string
  Manifest* = object
    database*: string
    proposalDir*: string
    sessionDir*: string
    roots*: seq[RootSpec]

proc scalar(value: string): string =
  result = value.strip
  if result.len >= 2 and result[0] == '"' and result[^1] == '"':
    result = result[1 .. ^2]

proc resolved(value, base: string): string =
  let expanded = value.expandTilde
  result =
    if expanded.isAbsolute: expanded.normalizedPath
    else: absolutePath(expanded, base).normalizedPath
  # Canonicalised once it exists, because `canonicalForCreation` canonicalises
  # the candidate: Windows hands out temporary directories in the 8.3 short
  # form (`RUNNER~1`) while `expandFilename` returns the long one, and a root
  # kept in the short form matches no path under it.
  if result.dirExists or result.fileExists:
    result = result.expandFilename.normalizedPath

proc pathWithin(candidate, root: string): bool =
  candidate == root or candidate.startsWith(root & DirSep)

proc canonicalForCreation(path: string): string =
  var existing = path
  var suffix: seq[string]
  while not dirExists(existing) and not fileExists(existing):
    let parent = existing.parentDir
    if parent == existing or parent.len == 0:
      raise newException(ManifestError, "cannot resolve path: " & path)
    suffix.insert(existing.lastPathPart, 0)
    existing = parent
  result = expandFilename(existing)
  for component in suffix:
    result = result / component
  result = result.normalizedPath

proc traversesLink(candidate, root: string): bool =
  ## Whether any component between `root` and `candidate` is a symbolic link.
  ##
  ## Resolving the path cannot answer this everywhere: `expandFilename` is
  ## `GetFullPathName` on Windows, which normalises without following a reparse
  ## point, so a write directory replaced by a junction still looked as though
  ## it sat inside the roots. Refusing the traversal needs no resolution and
  ## says the same thing on every platform.
  var current = candidate
  while current.len > root.len and current.startsWith(root):
    if symlinkExists(current): return true
    let parent = current.parentDir
    if parent == current: break
    current = parent
  false

proc containsPath*(manifest: Manifest; candidate: string): bool =
  let canonical = canonicalForCreation(candidate)
  for root in manifest.roots:
    if canonical.pathWithin(root.path):
      return not traversesLink(canonical, root.path)

proc secureWriteDirectory*(manifest: Manifest; path: string): string =
  result = canonicalForCreation(path)
  if not manifest.containsPath(result):
    raise newException(ManifestError, "write area is outside the allowed roots: " & path)

proc loadManifest*(path: string): Manifest =
  if not fileExists(path):
    raise newException(ManifestError, "manifest does not exist: " & path)
  let base = path.absolutePath.parentDir
  var inRoot = false
  let lines = readFile(path).splitLines
  for number, rawLine in lines.pairs:
    let line = rawLine.strip
    if line.len == 0 or line.startsWith("#"): continue
    if line == "[[roots]]":
      result.roots.add(RootSpec(visibility: "private"))
      inRoot = true
      continue
    let separator = line.find('=')
    if separator <= 0:
      raise newException(ManifestError, "invalid TOML line " & $(number + 1))
    let key = line[0 ..< separator].strip
    let value = scalar(line[separator + 1 .. ^1])
    if inRoot:
      case key
      of "name": result.roots[^1].name = value
      of "path": result.roots[^1].path = resolved(value, base)
      of "visibility": result.roots[^1].visibility = value
      else: raise newException(ManifestError, "unknown root key: " & key)
    else:
      case key
      of "version":
        if value != "1":
          raise newException(ManifestError, "unsupported manifest version: " & value)
      of "database": result.database = resolved(value, base)
      of "proposal_dir": result.proposalDir = resolved(value, base)
      of "session_dir": result.sessionDir = resolved(value, base)
      else: raise newException(ManifestError, "unknown manifest key: " & key)
  if result.database.len == 0:
    raise newException(ManifestError, "database is required")
  if result.roots.len == 0:
    raise newException(ManifestError, "at least one root is required")
  for root in result.roots.mitems:
    if root.name.len == 0 or root.path.len == 0:
      raise newException(ManifestError, "each root requires name and path")
    if root.visibility notin ["private", "team", "public"]:
      raise newException(ManifestError, "invalid root visibility: " &
          root.visibility)
    if not dirExists(root.path):
      raise newException(ManifestError, "root is not a directory: " & root.path)
    root.path = expandFilename(root.path)

  for writable in [result.proposalDir, result.sessionDir]:
    if writable.len > 0 and not result.containsPath(writable):
      raise newException(ManifestError, "write area is outside the allowed roots: " & writable)
