## SPDX-License-Identifier: Apache-2.0
import std/[os, times, unittest]
import UniContext/[memory/writer, text/markdown]
import UniContext/workspace/manifest

proc removeTree(path: string) =
  if not dirExists(path): return
  for kind, child in walkDir(path):
    if kind == pcDir: removeTree(child)
    else: removeFile(child)
  removeDir(path)

suite "Append-only writes":
  test "proposal and session log remain valid new Markdown files":
    let base = getTempDir() / ("unicontext-writer-" & $getTime().toUnix)
    createDir(base)
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
    let manifest = loadManifest(manifestPath)
    let proposalPath = propose(manifest, "proposal.writer.fixture",
      "Candidate lesson",
      "Evidence must accompany memory.", @["test_writer:pass"])
    check fileExists(proposalPath)
    check parseMarkdown(readFile(proposalPath), proposalPath).validate.len == 0
    expect MemoryWriteError:
      discard propose(manifest, "proposal.writer.fixture", "Duplicate",
          "Forbidden", @[])

    let startPath = sessionStart(manifest, "writer-fixture", "unicontext", "Test the log")
    let updatePath = sessionUpdate(manifest, "writer-fixture", "tests-pass",
      "Writer tests pass.")
    let closePath = sessionClose(manifest, "writer-fixture", "Log validated", "Human review")
    for path in [startPath, updatePath, closePath]:
      check parseMarkdown(readFile(path), path).validate.len == 0
    expect MemoryWriteError:
      discard sessionClose(manifest, "writer-fixture", "Overwrite", "")

    removeTree(base)

  test "rejects write directories redirected through symbolic links":
    let suffix = $getTime().toUnix
    let base = getTempDir() / ("unicontext-writer-link-" & suffix)
    let outside = getTempDir() / ("unicontext-writer-outside-" & suffix)
    createDir(base)
    createDir(outside)
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
    let manifest = loadManifest(manifestPath)
    createDir(base / "sessions")
    createSymlink(outside, base / "sessions" / "redirected")
    expect ManifestError:
      discard sessionStart(manifest, "redirected", "unicontext", "Must stay inside the root")

    removeTree(base)
    removeTree(outside)
