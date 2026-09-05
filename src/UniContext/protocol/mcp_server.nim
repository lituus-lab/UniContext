## SPDX-License-Identifier: Apache-2.0
import std/[json, os]
import UniMCP
import UniContext/[context/builder, database/store, domain/types, index/indexer]
import UniContext/memory/writer
import UniContext/workspace/[git_state, manifest]

const
  LatestProtocol* = "2025-11-25"
  SupportedProtocols = [LatestProtocol, "2025-06-18", "2024-11-05"]

type McpServer* = object
  manifest*: Manifest
  core: Server

proc property(kind, description: string): JsonNode =
  %*{"type": kind, "description": description}

proc toolsList(): JsonNode =
  %*{"tools": [
    {"name": "memory_search", "title": "Search knowledge",
     "description": "Run a sourced lexical search across the allowed knowledge roots.",
     "inputSchema": {"type": "object", "properties": {
       "query": property("string", "FTS5 terms to search for"),
       "limit": property("integer", "Maximum number of sections")},
           "required": ["query"]},
     "annotations": {"readOnlyHint": true, "destructiveHint": false,
       "idempotentHint": true, "openWorldHint": false}},
    {"name": "memory_get", "title": "Read knowledge note",
     "description": "Read all indexed sections of a note by stable identifier.",
     "inputSchema": {"type": "object", "properties": {
       "id": property("string", "Stable note identifier")}, "required": ["id"]},
     "annotations": {"readOnlyHint": true, "destructiveHint": false,
       "idempotentHint": true, "openWorldHint": false}},
    {"name": "memory_context", "title": "Compile context packet",
     "description": "Rank eligible sources and compile a budgeted context packet with provenance.",
     "inputSchema": {"type": "object", "properties": {
       "query": property("string", "Task or context requirement"),
       "budget_tokens": property("integer", "Approximate packet budget"),
       "repository": property("string", "Optional Git worktree to inspect")},
       "required": ["query"]},
     "annotations": {"readOnlyHint": true, "destructiveHint": false,
       "idempotentHint": true, "openWorldHint": false}},
    {"name": "memory_propose", "title": "Propose durable memory",
     "description": "Add a Markdown proposal to the inbox without changing canonical memory.",
     "inputSchema": {"type": "object", "properties": {
       "id": property("string", "Identifier starting with proposal."),
       "title": property("string", "Proposal title"),
       "summary": property("string", "Proposed durable summary"),
       "evidence": {"type": "array", "items": {"type": "string"}}},
       "required": ["id", "title", "summary"]},
     "annotations": {"readOnlyHint": false, "destructiveHint": false,
       "idempotentHint": false, "openWorldHint": false}},
    {"name": "session_start", "title": "Start work session",
     "description": "Create the first event in an immutable Markdown session log.",
     "inputSchema": {"type": "object", "properties": {
       "session_id": property("string", "Safe session identifier"),
       "project": property("string", "Related project"),
       "objective": property("string", "Exact objective")},
       "required": ["session_id", "project", "objective"]},
     "annotations": {"readOnlyHint": false, "destructiveHint": false,
       "idempotentHint": false, "openWorldHint": false}},
    {"name": "session_update", "title": "Add session event",
     "description": "Add a named event without rewriting existing events.",
     "inputSchema": {"type": "object", "properties": {
       "session_id": property("string", "Session identifier"),
       "event_id": property("string", "Unique event identifier"),
       "summary": property("string", "State, evidence, and hypotheses")},
       "required": ["session_id", "event_id", "summary"]},
     "annotations": {"readOnlyHint": false, "destructiveHint": false,
       "idempotentHint": false, "openWorldHint": false}},
    {"name": "session_close", "title": "Close work session",
     "description": "Add the final session event without changing its history.",
     "inputSchema": {"type": "object", "properties": {
       "session_id": property("string", "Session identifier"),
       "outcome": property("string", "Verified outcome"),
       "next_action": property("string", "Precise next action")},
       "required": ["session_id", "outcome"]},
     "annotations": {"readOnlyHint": false, "destructiveHint": false,
       "idempotentHint": false, "openWorldHint": false}}
  ]}

proc hitJson(hit: SearchHit): JsonNode =
  %*{"id": hit.noteId, "path": hit.path, "heading": hit.heading,
    "content": hit.content, "type": hit.noteType, "status": hit.status,
    "visibility": hit.visibility, "authority": hit.authority,
    "updated": hit.updated, "review_after": hit.reviewAfter,
    "root": hit.rootName}

proc packetJson(packet: ContextPacket; indexFresh: bool): JsonNode =
  var sources = newJArray()
  for source in packet.sources:
    sources.add(%*{"id": source.noteId, "path": source.path,
      "heading": source.heading, "authority": source.authority,
      "updated": source.updated, "stale": source.stale})
  %*{"context_version": packet.version, "query": packet.query,
    "budget_tokens": packet.budgetTokens,
    "estimated_tokens": packet.estimatedTokens,
    "knowledge_index_fresh": indexFresh,
    "rendered_context": packet.rendered,
    "git": {"requested_path": packet.git.requestedPath, "root": packet.git.root,
      "branch": packet.git.branch, "commit": packet.git.commit,
      "status": packet.git.status, "diff": packet.git.diff,
      "available": packet.git.available, "truncated": packet.git.truncated,
      "warning": packet.git.warning},
    "sources": sources, "warnings": packet.warnings}

proc argument(arguments: JsonNode; key: string): string =
  if arguments.kind != JObject or not arguments.hasKey(key) or
      arguments[key].kind != JString:
    raise newException(ValueError, "required string argument: " & key)
  arguments[key].getStr

proc optionalArgument(arguments: JsonNode; key: string): string =
  if arguments.kind == JObject and arguments.hasKey(key):
    if arguments[key].kind != JString:
      raise newException(ValueError, "expected string argument: " & key)
    result = arguments[key].getStr

proc stringArray(arguments: JsonNode; key: string): seq[string] =
  if not arguments.hasKey(key): return
  if arguments[key].kind != JArray:
    raise newException(ValueError, "expected string array: " & key)
  for item in arguments[key]:
    if item.kind != JString:
      raise newException(ValueError, "expected string array: " & key)
    result.add(item.getStr)

proc callTool(manifest: Manifest; name: string; arguments: JsonNode): JsonNode =
  var database = openStore(manifest.database)
  defer: database.close
  database.initialize
  case name
  of "memory_search":
    let query = arguments.argument("query")
    let limit = if arguments.hasKey("limit"): arguments["limit"].getInt else: 10
    if limit < 1 or limit > 100:
      raise newException(ValueError, "limit must be between 1 and 100")
    var hits = newJArray()
    for hit in database.search(query, limit): hits.add(hit.hitJson)
    toolResult(%*{"hits": hits, "knowledge_index_fresh": manifest.indexIsFresh})
  of "memory_get":
    let noteId = arguments.argument("id")
    var sections = newJArray()
    for hit in database.getNote(noteId): sections.add(hit.hitJson)
    toolResult(%*{"id": noteId, "sections": sections,
      "knowledge_index_fresh": manifest.indexIsFresh})
  of "memory_context":
    let query = arguments.argument("query")
    let budget = if arguments.hasKey("budget_tokens"): arguments[
        "budget_tokens"].getInt else: 4000
    if budget < MinBudgetTokens or budget > MaxBudgetTokens:
      raise newException(ValueError, "budget_tokens must be between " &
        $MinBudgetTokens & " and " & $MaxBudgetTokens)
    # The manifest authorises reads as it already authorises writes: without
    # this, a client could name any worktree on the host and read back its
    # branch, status and diff through the packet.
    let requested = arguments.optionalArgument("repository")
    let git =
      if requested.len == 0 or manifest.containsPath(requested):
        collectGitState(requested)
      else:
        GitState(requestedPath: requested,
          warning: "repository is outside the manifest's allowed roots")
    let indexFresh = manifest.indexIsFresh
    let initialWarnings = if indexFresh: @[] else:
      @["knowledge index is stale; rebuild it before relying on memory"]
    let packet = buildContextPacket(query, database.search(query, 50), budget,
        git = git,
      initialWarnings = initialWarnings)
    toolResult(packet.packetJson(indexFresh), text = packet.rendered)
  of "memory_propose":
    let path = propose(manifest, arguments.argument("id"),
      arguments.argument("title"), arguments.argument("summary"),
      arguments.stringArray("evidence"))
    toolResult(%*{"created": path, "canonical": false, "status": "proposed"})
  of "session_start":
    let path = sessionStart(manifest, arguments.argument("session_id"),
      arguments.argument("project"), arguments.argument("objective"))
    toolResult(%*{"created": path, "append_only": true})
  of "session_update":
    let path = sessionUpdate(manifest, arguments.argument("session_id"),
      arguments.argument("event_id"), arguments.argument("summary"))
    toolResult(%*{"created": path, "append_only": true})
  of "session_close":
    let path = sessionClose(manifest, arguments.argument("session_id"),
      arguments.argument("outcome"), arguments.optionalArgument("next_action"))
    toolResult(%*{"created": path, "append_only": true, "closed": true})
  else:
    raise newException(KeyError, "unknown tool: " & name)

proc descriptors(): seq[ToolDescriptor] =
  for item in toolsList()["tools"]:
    result.add(ToolDescriptor(name: item["name"].getStr, title: item[
        "title"].getStr,
      description: item["description"].getStr, inputSchema: item["inputSchema"],
      annotations: item["annotations"]))

proc newMcpServer*(manifestPath: string): McpServer =
  result.manifest = loadManifest(manifestPath)
  if not fileExists(result.manifest.database):
    raise newException(IOError, "knowledge index is missing; run unicontext index --manifest " &
      manifestPath)
  let capturedManifest = result.manifest
  result.core = newServer(ServerInfo(name: "unicontext", title: "UniContext",
    version: "0.1.0", description: "Private, sourced context compiler"),
    LatestProtocol,
    @SupportedProtocols, descriptors(),
    proc(name: string; arguments: JsonNode): JsonNode =
    callTool(capturedManifest, name, arguments),
    "Use current code and tests before stored memory; report conflicts.")

proc handle*(server: var McpServer; message: JsonNode): JsonNode =
  server.core.handle(message)

proc handleLine*(server: var McpServer; line: string): string =
  server.core.handleLine(line)

proc serveStdio*(manifestPath: string) =
  var server = newMcpServer(manifestPath)
  server.core.serveStdio
