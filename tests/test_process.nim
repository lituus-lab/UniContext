## SPDX-License-Identifier: Apache-2.0
import std/[json, os, osproc, streams, strutils, times, unittest]

const TestBinary = "/tmp/unicontext-test-cli"

proc removeTree(path: string) =
  if not dirExists(path): return
  for kind, child in walkDir(path):
    if kind == pcDir: removeTree(child)
    else: removeFile(child)
  removeDir(path)

proc run(arguments: openArray[string]; workingDirectory: string): tuple[output: string; code: int] =
  let process = startProcess(TestBinary, workingDir = workingDirectory, args = @arguments,
    options = {poStdErrToStdOut})
  result.output = process.outputStream.readAll
  result.code = process.waitForExit()
  process.close()

suite "CLI and MCP inter-process integration":
  test "rebuilds an index and replays the portable MCP fixture":
    check fileExists(TestBinary)
    let base = getTempDir() / ("unicontext-process-" & $getTime().toUnix)
    createDir(base)
    writeFile(base / "note.md", """---
id: decision.process.fixture
type: decision
status: accepted
visibility: private
authority: test
updated: 2026-08-21
---
# Process fixture

The stdio server returns this exact evidence.
""")
    let manifestPath = base / "unicontext.toml"
    writeFile(manifestPath, """version = 1
database = "runtime/index.sqlite"
proposal_dir = "inbox/agent-proposals"
session_dir = "sessions"

[[roots]]
name = "fixture"
path = "."
visibility = "private"
""")

    let missingIndex = run(["context", "--manifest", manifestPath,
      "--query", "process fixture"], base)
    check missingIndex.code != 0
    check "knowledge index is missing" in missingIndex.output

    let indexed = run(["index", "--manifest", manifestPath], base)
    check indexed.code == 0
    check "documents" in indexed.output

    let freshStatus = run(["status", "--manifest", manifestPath], base)
    check freshStatus.code == 0
    check parseJson(freshStatus.output)["fresh"].getBool

    writeFile(base / "note.md", readFile(base / "note.md") & "\nChanged after indexing.\n")
    let staleStatus = run(["status", "--manifest", manifestPath], base)
    check staleStatus.code == 0
    check not parseJson(staleStatus.output)["fresh"].getBool
    let staleContext = run(["context", "--manifest", manifestPath,
      "--query", "process fixture"], base)
    check staleContext.code == 0
    let stalePacket = parseJson(staleContext.output)
    check not stalePacket["knowledge_index_fresh"].getBool
    check "WARNING: knowledge index is stale" in stalePacket["rendered_context"].getStr

    let reindexed = run(["index", "--manifest", manifestPath], base)
    check reindexed.code == 0

    let server = startProcess(TestBinary, workingDir = base,
      args = @["serve", "--manifest", manifestPath], options = {})
    let requestsPath = currentSourcePath.parentDir.parentDir / "fixtures" / "mcp" / "initialize.jsonl"
    var responses: seq[JsonNode]
    for requestLine in readFile(requestsPath).splitLines:
      if requestLine.len == 0: continue
      server.inputStream.writeLine(requestLine)
      server.inputStream.flush()
      if "notifications/initialized" notin requestLine:
        responses.add(parseJson(server.outputStream.readLine()))
    check responses.len == 2
    check responses[0]["result"]["protocolVersion"].getStr == "2025-11-25"
    check responses[1]["result"]["tools"].len == 7

    server.inputStream.writeLine($( %*{
      "jsonrpc": "2.0", "id": 3, "method": "tools/call",
      "params": {"name": "memory_get",
        "arguments": {"id": "decision.process.fixture"}}
    }))
    server.inputStream.flush()
    let called = parseJson(server.outputStream.readLine())
    check called["result"]["isError"].getBool == false
    check "The stdio server returns this exact evidence." in
      called["result"]["structuredContent"]["sections"][0]["content"].getStr

    server.inputStream.writeLine("{broken")
    server.inputStream.flush()
    let parseFailure = parseJson(server.outputStream.readLine())
    check parseFailure["error"]["code"].getInt == -32700

    server.inputStream.close()
    check server.waitForExit() == 0
    server.close()
    removeTree(base)
