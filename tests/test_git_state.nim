## SPDX-License-Identifier: Apache-2.0
import std/[os, osproc, strutils, times, unittest]
import UniContext/workspace/git_state

proc git(repository: string; arguments: openArray[string]) =
  let process = startProcess("git", workingDir = repository, args = @arguments,
    options = {poUsePath, poStdErrToStdOut})
  let code = process.waitForExit()
  process.close()
  check code == 0

suite "Bounded live Git context":
  test "collects repository identity, status, and working-tree diff":
    let base = getTempDir() / ("unicontext-git-" & $getTime().toUnix)
    createDir(base)
    git(base, ["init", "--quiet"])
    git(base, ["config", "user.name", "UniContext Test"])
    git(base, ["config", "user.email", "unicontext@example.invalid"])
    git(base, ["config", "commit.gpgsign", "false"])
    writeFile(base / "tracked.txt", "initial\n")
    git(base, ["add", "tracked.txt"])
    git(base, ["commit", "--quiet", "-m", "Initial fixture"])
    writeFile(base / "tracked.txt", "initial\nchanged\n")
    writeFile(base / "staged.txt", "staged\n")
    git(base, ["add", "staged.txt"])
    writeFile(base / "untracked.txt", "new\n")

    let state = collectGitState(base)
    check state.available
    check state.root.endsWith(base.lastPathPart)
    check state.commit.len == 40
    check "tracked.txt" in state.status
    check "staged.txt" in state.status
    check "untracked.txt" in state.status
    check "# Staged changes" in state.diff
    check "+staged" in state.diff
    check "# Unstaged changes" in state.diff
    check "+changed" in state.diff
    check not state.truncated

    removeDir(base)

  test "reports a non-repository without raising":
    let base = getTempDir() / ("unicontext-not-git-" & $getTime().toUnix)
    createDir(base)
    let state = collectGitState(base)
    check not state.available
    check "not a Git worktree" in state.warning
    removeDir(base)
