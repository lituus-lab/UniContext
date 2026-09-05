## SPDX-License-Identifier: Apache-2.0
import std/[strutils, unittest]
import UniContext/domain/types
import UniContext/text/markdown

suite "Canonical Markdown":
  test "flat frontmatter and sections":
    let note = parseMarkdown("""---
id: decision.example
type: decision
status: accepted
visibility: private
authority: maintainer
updated: 2026-08-21
---
# Example decision

Canonical summary.

## Evidence

A reproducible test.
""", "example.md")
    check note.title == "Example decision"
    check note.frontmatter.get("id") == "decision.example"
    check note.sections.len == 2
    check note.sections[1].heading == "Evidence"
    check note.validate.len == 0

  test "missing required metadata":
    let note = parseMarkdown("""---
id: incomplete
---
# Incomplete
""", "incomplete.md")
    check note.validate.len == 5

  test "keeps heading-like lines inside fenced code blocks":
    let note = parseMarkdown("""---
id: lesson.fenced-code
type: lesson
status: accepted
visibility: private
authority: test
updated: 2026-08-21
---
# Fenced code

```markdown
# This is code, not a section
```

## Actual section

Actual content.
""", "fenced.md")
    check note.sections.len == 2
    check "# This is code" in note.sections[0].content
    check note.sections[1].heading == "Actual section"

  test "a longer fence is not closed by a shorter one inside it":
    let note = parseMarkdown("""---
id: lesson.long-fence
type: lesson
status: accepted
visibility: private
authority: test
updated: 2026-08-21
---
# Nested fences

````markdown
```
# Still code, inside the outer block
```
````

## Actual section

Actual content.
""", "long-fence.md")
    check note.sections.len == 2
    check "# Still code" in note.sections[0].content
    check note.sections[1].heading == "Actual section"

  test "a four-space-indented fence stays inside the block":
    # The trap is the unindented heading after it: if the indented fence closed
    # the block, that line would become a third section.
    let note = parseMarkdown("""---
id: lesson.indented-fence
type: lesson
status: accepted
visibility: private
authority: test
updated: 2026-08-21
---
# Indented fences

```markdown
    ```
## Not a heading, this is inside the block
```

## Actual section

Actual content.
""", "indented-fence.md")
    check note.sections.len == 2
    check "## Not a heading" in note.sections[0].content
    check note.sections[1].heading == "Actual section"

  test "rejects duplicate YAML keys and invalid enum values":
    expect MarkdownError:
      discard parseMarkdown("""---
id: duplicate
id: duplicate-again
---
# Duplicate
""", "duplicate.md")

    let invalid = parseMarkdown("""---
id: invalid
type: unknown
status: final
visibility: secret
authority: robot
updated: 21-08-2026
---
# Invalid
""", "invalid.md")
    check invalid.validate.len == 5
