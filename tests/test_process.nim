## SPDX-License-Identifier: Apache-2.0
import std/[json, os, osproc, streams, strutils, times, unittest]

const Exe = when defined(windows): ".exe" else: ""
const TestBinary = currentSourcePath().parentDir.parentDir / "build" /
  ("unicontext" & Exe)
  ## Built by the `cli` task, beside the suites. A hard-coded /tmp path is not
  ## a path on Windows, and a sibling checkout is not a build dependency.

proc removeTree(path: string) =
  if not dirExists(path): return
  for kind, child in walkDir(path):
    if kind == pcDir: removeTree(child)
    else: removeFile(child)
  removeDir(path)

proc run(arguments: openArray[string]; workingDirectory: string): tuple[
    output: string; code: int] =
  let process = startProcess(TestBinary, workingDir = workingDirectory,
    args = @arguments,
    options = {poStdErrToStdOut})
  # Closed however this returns: a read that raises would otherwise leak the
  # handle, and a suite that leaks one per failing case runs out of them.
  defer: process.close()
  # Exit first, then read: on a Windows pipe `readAll` returns what happens to
  # be buffered rather than blocking to end of file, and CI captured exactly
  # one byte of the message. Safe here because the command's output is far
  # smaller than a pipe buffer -- draining after exit cannot deadlock at this
  # size, and nothing this CLI prints approaches it.
  result.code = process.waitForExit()
  result.output = process.outputStream.readAll

suite "CLI and MCP inter-process integration":
  test "rebuilds an index and replays the portable MCP fixture":
    check fileExists(TestBinary)
    let base = getTempDir() / ("unicontext-process-" & $getTime().toUnix)
    # Removed however this test ends: a failing check leaves the fixture behind
    # otherwise, and the next run indexes it.
    defer: removeTree(base)
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
    # Escaped, and with its length: a value that prints as one character is
    # either genuinely that, or an encoding that stops the terminal early.
    if "knowledge index is missing" notin missingIndex.output:
      echo "context exit ", missingIndex.code, ", ",
        missingIndex.output.len, " bytes: ", missingIndex.output.escape
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
    check "WARNING: knowledge index is stale" in stalePacket[
        "rendered_context"].getStr

    let reindexed = run(["index", "--manifest", manifestPath], base)
    check reindexed.code == 0

    let server = startProcess(TestBinary, workingDir = base,
      args = @["serve", "--manifest", manifestPath], options = {})
    # Ended however this test ends: a check that raises between here and the
    # orderly shutdown below would leave the server running on the fixture the
    # deferred cleanup is about to delete.
    defer: server.close()
    let requestsPath = currentSourcePath.parentDir.parentDir / "fixtures" /
        "mcp" / "initialize.jsonl"
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
