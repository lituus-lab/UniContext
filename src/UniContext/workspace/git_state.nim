## SPDX-License-Identifier: Apache-2.0
import std/[os, osproc, streams, strutils]
import UniContext/domain/types

const
  DefaultGitOutputLimit* = 12_000

proc runGit(repository: string; arguments: openArray[string];
    limit = DefaultGitOutputLimit): tuple[output: string; code: int] =
  ## At most `limit + 1` bytes are kept. The rest is read and discarded rather
  ## than left in the pipe: `readAll` on a repository whose diff is a gigabyte
  ## put the whole gigabyte in memory before `bounded` trimmed it, and simply
  ## stopping the read would block git on a full pipe instead.
  ##
  ## One byte past the limit, not exactly the limit: `bounded` decides that
  ## output was truncated by comparing against the same number, and a value cut
  ## to exactly it would be reported as complete.
  var process = startProcess("git", workingDir = repository, args = @arguments,
    options = {poUsePath, poStdErrToStdOut})
  defer: process.close()
  let stream = process.outputStream
  var chunk = newString(4096)
  while true:
    let read = stream.readData(addr chunk[0], chunk.len)
    if read <= 0: break
    if result.output.len <= limit:
      let keep = min(read, limit + 1 - result.output.len)
      result.output.add(chunk[0 ..< keep])
  result.output = result.output.strip
  result.code = process.waitForExit()

proc bounded(value: string; limit: int; truncated: var bool): string =
  if value.len <= limit:
    return value
  truncated = true
  result = value[0 ..< limit]
  result.add("\n[output truncated by UniContext]")

proc collectGitState*(repository: string;
    outputLimit = DefaultGitOutputLimit): GitState =
  result.requestedPath = repository
  if repository.len == 0:
    return
  let absolute = repository.expandTilde.absolutePath.normalizedPath
  result.requestedPath = absolute
  if not dirExists(absolute):
    result.warning = "repository path is not a directory: " & absolute
    return
  try:
    let root = runGit(absolute, ["rev-parse", "--show-toplevel"])
    if root.code != 0:
      result.warning = "path is not a Git worktree: " & absolute
      return
    result.root = root.output
    let branch = runGit(absolute, ["branch", "--show-current"])
    if branch.code == 0: result.branch = branch.output
    let commit = runGit(absolute, ["rev-parse", "HEAD"])
    if commit.code == 0: result.commit = commit.output
    if result.branch.len == 0 and result.commit.len > 0:
      result.branch = "(detached HEAD)"
    let status = runGit(absolute, ["status", "--short", "--branch",
        "--untracked-files=normal"])
    if status.code == 0:
      result.status = bounded(status.output, outputLimit div 3,
          result.truncated)
    let staged = runGit(absolute,
      ["diff", "--cached", "--no-ext-diff", "--unified=1", "--"], outputLimit)
    let unstaged = runGit(absolute, ["diff", "--no-ext-diff", "--unified=1", "--"], outputLimit)
    var combinedDiff: string
    if staged.code == 0 and staged.output.len > 0:
      combinedDiff.add("# Staged changes\n" & staged.output)
    if unstaged.code == 0 and unstaged.output.len > 0:
      if combinedDiff.len > 0: combinedDiff.add("\n\n")
      combinedDiff.add("# Unstaged changes\n" & unstaged.output)
    result.diff = bounded(combinedDiff, outputLimit - result.status.len,
        result.truncated)
    result.available = true
  except OSError as error:
    result.warning = "cannot execute git: " & error.msg
