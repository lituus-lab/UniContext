## SPDX-License-Identifier: Apache-2.0
import std/[sequtils, json, os, strutils, times, unittest]
import UniContext/[index/indexer, protocol/mcp_server]
import UniContext/workspace/manifest

proc request(id: int; rpcMethod: string; params = newJObject()): JsonNode =
  %*{"jsonrpc": "2.0", "id": id, "method": rpcMethod, "params": params}

suite "MCP stdio 2025-11-25":
  test "returns portable JSON-RPC errors for malformed input":
    var server: McpServer
    let fixtureDir = currentSourcePath.parentDir.parentDir / "fixtures" / "mcp"
    let requests = readFile(fixtureDir / "errors.requests.jsonl").splitLines
    let expected = readFile(fixtureDir / "errors.expected.jsonl").splitLines
    check requests.len == expected.len
    for index in 0 ..< requests.len:
      if requests[index].len == 0: continue
      check parseJson(server.handleLine(requests[index])) == parseJson(expected[index])

  test "rejects malformed method parameters with portable errors":
    let base = getTempDir() / ("unicontext-mcp-errors-" & $getTime().toUnix)
    createDir(base)
    let manifestPath = base / "unicontext.toml"
    writeFile(manifestPath, """version = 1
database = "index.sqlite"
proposal_dir = "proposals"
session_dir = "sessions"

[[roots]]
name = "fixture"
path = "."
visibility = "private"
""")
    discard rebuildIndex(loadManifest(manifestPath))
    var server = newMcpServer(manifestPath)
    let missingInitialize = server.handle(request(1, "initialize"))
    check missingInitialize["error"]["code"].getInt == -32602
    let wrongInitialize = server.handle(request(2, "initialize", %*{
        "protocolVersion": 1}))
    check wrongInitialize["error"]["code"].getInt == -32602
    discard server.handle(request(3, "initialize", %*{
      "protocolVersion": LatestProtocol, "capabilities": {},
      "clientInfo": {"name": "fixture", "version": "1"}}))
    discard server.handle(%*{"jsonrpc": "2.0",
        "method": "notifications/initialized"})
    let missingToolName = server.handle(request(4, "tools/call", %*{}))
    check missingToolName["result"]["isError"].getBool
    let wrongArguments = server.handle(request(5, "tools/call", %*{
      "name": "memory_search", "arguments": []}))
    check wrongArguments["result"]["isError"].getBool
    removeFile(manifestPath)
    removeFile(base / "index.sqlite")
    for suffix in ["-wal", "-shm"]:
      let sidecar = base / ("index.sqlite" & suffix)
      if fileExists(sidecar): removeFile(sidecar)
    removeDir(base)

  test "initializes, lists, and calls read and proposal tools":
    let base = getTempDir() / ("unicontext-mcp-" & $getTime().toUnix)
    createDir(base)
    writeFile(base / "note.md", """---
id: decision.mcp.fixture
type: decision
status: accepted
visibility: private
authority: maintainer
updated: 2026-08-21
review_after: 2027-01-01
---
# Fixture MCP

Provenance must accompany shared context.
""")
    let manifestPath = base / "unicontext.toml"
    writeFile(manifestPath, """version = 1
database = "index.sqlite"
proposal_dir = "inbox/agent-proposals"
session_dir = "sessions"

[[roots]]
name = "fixture"
path = "."
visibility = "private"
""")
    let manifest = loadManifest(manifestPath)
    discard rebuildIndex(manifest)
    var server = newMcpServer(manifestPath)

    let historical = server.handle(request(0, "initialize", %*{
      "protocolVersion": "2024-11-05", "capabilities": {},
      "clientInfo": {"name": "maki", "version": "0.2.9"}}))
    check historical["result"]["protocolVersion"].getStr == "2024-11-05"

    let initialized = server.handle(request(1, "initialize", %*{
      "protocolVersion": "2025-11-25", "capabilities": {},
      "clientInfo": {"name": "fixture", "version": "1"}}))
    check initialized["result"]["protocolVersion"].getStr == "2025-11-25"
    check initialized["result"]["capabilities"].hasKey("tools")
    check not initialized["result"]["capabilities"].hasKey("prompts")
    discard server.handle(%*{"jsonrpc": "2.0",
        "method": "notifications/initialized"})

    let listed = server.handle(request(2, "tools/list"))
    check listed["result"]["tools"].len == 7
    var contextTool: JsonNode
    for tool in listed["result"]["tools"]:
      if tool["name"].getStr == "memory_context": contextTool = tool
    check contextTool["inputSchema"]["properties"].hasKey("repository")
    let prompts = server.handle(request(5, "prompts/list"))
    check prompts["error"]["code"].getInt == -32601

    let called = server.handle(request(3, "tools/call", %*{
      "name": "memory_context",
      "arguments": {"query": "context provenance", "budget_tokens": 500}}))
    check called["result"]["isError"].getBool == false
    check called["result"]["structuredContent"]["sources"].len == 1
    check called["result"]["structuredContent"]["sources"][0]["id"].getStr ==
      "decision.mcp.fixture"
    check called["result"]["structuredContent"].hasKey("git")
    check called["result"]["content"][0]["text"].getStr.startsWith("# Context packet v1")
    check not called["result"]["content"][0]["text"].getStr.startsWith("{")

    # A worktree outside the manifest is refused rather than read: the packet
    # comes back with a warning and no branch, commit, status or diff.
    let outside = server.handle(request(6, "tools/call", %*{
      "name": "memory_context",
      "arguments": {"query": "context provenance", "budget_tokens": 500,
        "repository": getCurrentDir()}}))
    check outside["result"]["isError"].getBool == false
    let git = outside["result"]["structuredContent"]["git"]
    check git["available"].getBool == false
    check "outside the manifest" in outside["result"]["structuredContent"][
      "warnings"].getElems.mapIt(it.getStr).join(" ")

    let proposed = server.handle(request(4, "tools/call", %*{
      "name": "memory_propose",
      "arguments": {"id": "proposal.mcp.fixture", "title": "Fixture proposal",
        "summary": "The proposal remains non-canonical.", "evidence": [
            "test_mcp:pass"]}}))
    check proposed["result"]["isError"].getBool == false
    let proposalPath = base / "inbox" / "agent-proposals" / "proposal.mcp.fixture.md"
    check fileExists(proposalPath)

    removeFile(base / "note.md")
    removeFile(manifestPath)
    removeFile(base / "index.sqlite")
    for suffix in ["-wal", "-shm"]:
      let sidecar = base / ("index.sqlite" & suffix)
      if fileExists(sidecar): removeFile(sidecar)
    removeFile(proposalPath)
    removeDir(base / "inbox" / "agent-proposals")
    removeDir(base / "inbox")
    removeDir(base)
