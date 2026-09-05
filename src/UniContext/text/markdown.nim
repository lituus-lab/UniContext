## SPDX-License-Identifier: Apache-2.0
import std/[json, sets, strutils, times]
import UniContext/domain/types

type MarkdownError* = object of ValueError

proc stripScalar(value: string): string =
  result = value.strip
  if result.len >= 2 and result[0] == '"' and result[^1] == '"':
    try:
      return parseJson(result).getStr
    except CatchableError:
      raise newException(MarkdownError, "invalid double-quoted YAML scalar")
  if result.len >= 2 and result[0] == '\'' and result[^1] == '\'':
    result = result[1 .. ^2]

proc parseFrontmatter(lines: seq[string]; stop: var int): Frontmatter =
  if lines.len == 0 or lines[0].strip != "---":
    raise newException(MarkdownError, "missing YAML frontmatter")
  var index = 1
  var keys = initHashSet[string]()
  while index < lines.len and lines[index].strip != "---":
    let line = lines[index]
    if line.strip.len > 0 and not line.strip.startsWith("#"):
      let separator = line.find(':')
      if separator <= 0:
        raise newException(MarkdownError,
            "invalid flat YAML property at line " & $(index + 1))
      let key = line[0 ..< separator].strip
      let value = stripScalar(line[separator + 1 .. ^1])
      if key.len == 0:
        raise newException(MarkdownError, "empty YAML key at line " & $(index + 1))
      if key in keys:
        raise newException(MarkdownError, "duplicate YAML key at line " & $(
            index + 1) & ": " & key)
      keys.incl(key)
      result.fields.add((key, value))
    inc index
  if index >= lines.len:
    raise newException(MarkdownError, "unterminated YAML frontmatter")
  stop = index + 1

proc headingOf(line: string; level: var int): string =
  level = 0
  while level < line.len and line[level] == '#':
    inc level
  if level == 0 or level > 6 or level >= line.len or line[level] != ' ':
    level = 0
    return ""
  result = line[level + 1 .. ^1].strip

proc fenceRun(line: string): string =
  ## The leading run of ``` or ~~~ characters, empty when the line opens no
  ## fenced block.
  if line.len < 3 or line[0] notin {'`', '~'}: return ""
  var length = 0
  while length < line.len and line[length] == line[0]: inc length
  if length < 3: return ""
  line[0 ..< length]

proc parseMarkdown*(content, path: string): KnowledgeNote =
  let lines = content.splitLines
  var bodyStart = 0
  result.path = path
  result.frontmatter = parseFrontmatter(lines, bodyStart)

  var current = Section(heading: "Introduction", level: 0)
  var fence: string
  for index in bodyStart ..< lines.len:
    let stripped = lines[index].strip
    if fence.len > 0:
      current.content.add(lines[index])
      current.content.add('\n')
      # A closing fence is at least as long as the one that opened the block
      # and carries nothing else: inside a four-backtick block, a line of three
      # is content. Keeping only three characters closed it there.
      let closing = fenceRun(stripped)
      # At most three spaces may precede a closing fence; four or more make the
      # line indented code inside the block, so the raw line decides, not the
      # stripped one.
      var indent = 0
      while indent < lines[index].len and lines[index][indent] ==
          ' ': inc indent
      if indent <= 3 and closing.len >= fence.len and closing[0] == fence[0] and
          stripped.len == closing.len:
        fence = ""
      continue
    let opening = fenceRun(stripped)
    if opening.len > 0:
      fence = opening
      current.content.add(lines[index])
      current.content.add('\n')
      continue
    var level = 0
    let heading = headingOf(lines[index], level)
    if heading.len > 0:
      if current.content.strip.len > 0:
        current.content = current.content.strip
        result.sections.add(current)
      current = Section(heading: heading, level: level)
      if result.title.len == 0 and level == 1:
        result.title = heading
    else:
      current.content.add(lines[index])
      current.content.add('\n')
  if current.content.strip.len > 0 or current.heading != "Introduction":
    current.content = current.content.strip
    result.sections.add(current)

  if result.title.len == 0:
    result.title = result.frontmatter.get("title")
  if result.title.len == 0:
    raise newException(MarkdownError, "missing level-one heading or title property")

proc isIsoDate(value: string): bool =
  ## YYYY-MM-DD, shape only -- `parse` below decides whether the date exists.
  ## A proc rather than one folded condition: nimpretty rewrites the folded
  ## form into `'-'ornot`, which does not parse.
  value.len == 10 and value[4] == '-' and value[7] == '-' and
    value[0 .. 3].allCharsInSet(Digits) and
    value[5 .. 6].allCharsInSet(Digits) and
    value[8 .. 9].allCharsInSet(Digits)

proc validate*(note: KnowledgeNote): seq[string] =
  const required = ["id", "type", "status", "visibility", "authority", "updated"]
  for key in required:
    if not note.frontmatter.has(key):
      result.add("missing required property: " & key)
  if note.frontmatter.has("visibility") and
      note.frontmatter.get("visibility") notin ["private", "team", "public"]:
    result.add("visibility must be private, team, or public")
  if note.frontmatter.has("status") and note.frontmatter.get("status") notin
      ["draft", "proposed", "active", "accepted", "superseded", "archived"]:
    result.add("invalid status")
  if note.frontmatter.has("authority") and note.frontmatter.get(
      "authority") notin ["agent", "human", "maintainer", "test", "code", "external"]:
    result.add("invalid authority")
  if note.frontmatter.has("type") and note.frontmatter.get("type") notin
      ["system", "policy", "schema", "project", "decision", "constraint",
       "lesson",
       "experiment", "session", "proposal"]:
    result.add("invalid type")

  let noteId = note.frontmatter.get("id")
  if noteId.len > 0:
    if noteId.len > 160:
      result.add("id is too long")
    else:
      for character in noteId:
        if character notin {'a'..'z', 'A'..'Z', '0'..'9', '.', '_', '-'}:
          result.add("id must contain only ASCII letters, digits, dots, underscores, or hyphens")
          break

  for key in ["created", "updated", "review_after"]:
    let value = note.frontmatter.get(key)
    if value.len > 0 and not value.isIsoDate:
      result.add(key & " must use YYYY-MM-DD")
    elif value.len > 0:
      try:
        discard parse(value, "yyyy-MM-dd")
      except TimeParseError:
        result.add(key & " is not a valid calendar date")
