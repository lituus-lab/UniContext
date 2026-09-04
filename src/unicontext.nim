## SPDX-License-Identifier: Apache-2.0
import std/[json, os, strformat, strutils]
import UniContext/[context/builder, database/store, index/indexer]
import UniContext/protocol/mcp_server
import UniContext/workspace/[git_state, manifest]

proc usage() =
  echo """UniContext prototype 0.1.0
usage:
  unicontext index  --root PATH --db PATH
  unicontext index  --manifest PATH
  unicontext search --db PATH --query TEXT [--limit N]
  unicontext context --manifest PATH --query TEXT [--budget TOKENS] [--repository PATH]
  unicontext status --manifest PATH
  unicontext serve --manifest PATH
"""

proc options(): tuple[root, database, query, manifest, repository: string; limit, budget: int] =
  result.limit = 10
  result.budget = 4000
  let arguments = commandLineParams()
  var index = 1
  while index < arguments.len:
    var key = arguments[index]
    if not key.startsWith("-"):
        raise newException(ValueError, "unexpected argument: " & key)
    key = key.strip(chars = {'-'})
    var value: string
    let separator = key.find('=')
    if separator >= 0:
      value = key[separator + 1 .. ^1]
      key = key[0 ..< separator]
    else:
      inc index
      if index >= arguments.len:
        raise newException(ValueError, "missing value for --" & key)
      value = arguments[index]
    case key
    of "root": result.root = value
    of "db": result.database = value
    of "query", "q": result.query = value
    of "manifest": result.manifest = value
    of "repository", "repo": result.repository = value
    of "limit": result.limit = parseInt(value)
    of "budget": result.budget = parseInt(value)
    else: raise newException(ValueError, "unknown option: --" & key)
    inc index

proc main() =
  if paramCount() == 0:
    usage()
    quit(2)
  let command = paramStr(1)
  let config = options()
  case command
  of "index":
    let report = if config.manifest.len > 0:
      rebuildIndex(loadManifest(config.manifest))
    else:
      if config.root.len == 0 or config.database.len == 0:
        raise newException(ValueError, "index requires --manifest or both --root and --db")
      rebuildIndex(config.root, config.database)
    echo &"{report.documents} documents, {report.sections} sections indexed, " &
      &"fingerprint {report.fingerprint}"
  of "search":
    if config.database.len == 0 or config.query.len == 0:
      raise newException(ValueError, "search requires --db and --query")
    var database = openStore(config.database)
    defer: database.close
    database.initialize
    var output = newJArray()
    for hit in database.search(config.query, config.limit):
      output.add(%*{
        "id": hit.noteId, "path": hit.path, "heading": hit.heading,
        "snippet": hit.snippet, "type": hit.noteType, "status": hit.status,
        "visibility": hit.visibility, "authority": hit.authority, "updated": hit.updated
      })
    echo output.pretty
  of "context":
    if config.manifest.len == 0 or config.query.len == 0:
      raise newException(ValueError, "context requires --manifest and --query")
    let manifest = loadManifest(config.manifest)
    if not fileExists(manifest.database):
      raise newException(IOError, "knowledge index is missing; run unicontext index --manifest " &
        config.manifest)
    var database = openStore(manifest.database)
    defer: database.close
    database.initialize
    let git = collectGitState(config.repository)
    let indexFresh = manifest.indexIsFresh
    let initialWarnings = if indexFresh: @[] else:
      @["knowledge index is stale; rebuild it before relying on memory"]
    let packetWithStatus = buildContextPacket(config.query,
      database.search(config.query, max(config.limit, 50)), config.budget, git = git,
      initialWarnings = initialWarnings)
    var sources = newJArray()
    for source in packetWithStatus.sources:
      sources.add(%*{"id": source.noteId, "path": source.path,
        "heading": source.heading, "authority": source.authority,
        "updated": source.updated, "stale": source.stale})
    echo (%*{"context_version": packetWithStatus.version, "query": packetWithStatus.query,
      "budget_tokens": packetWithStatus.budgetTokens,
      "estimated_tokens": packetWithStatus.estimatedTokens,
      "rendered_context": packetWithStatus.rendered, "sources": sources,
      "knowledge_index_fresh": indexFresh,
      "git": {"requested_path": packetWithStatus.git.requestedPath,
        "root": packetWithStatus.git.root, "branch": packetWithStatus.git.branch,
        "commit": packetWithStatus.git.commit, "status": packetWithStatus.git.status,
        "diff": packetWithStatus.git.diff, "available": packetWithStatus.git.available,
        "truncated": packetWithStatus.git.truncated,
        "warning": packetWithStatus.git.warning}, "warnings": packetWithStatus.warnings}).pretty
  of "status":
    if config.manifest.len == 0:
      raise newException(ValueError, "status requires --manifest")
    let manifest = loadManifest(config.manifest)
    echo (%*{"database": manifest.database, "exists": fileExists(manifest.database),
      "fresh": manifest.indexIsFresh,
      "corpus_fingerprint": manifest.corpusFingerprint}).pretty
  of "serve":
    if config.manifest.len == 0:
      raise newException(ValueError, "serve requires --manifest")
    serveStdio(config.manifest)
  else:
    usage()
    quit(2)

when isMainModule:
  try:
    main()
  except CatchableError as error:
    stderr.writeLine("unicontext: " & error.msg)
    quit(1)
