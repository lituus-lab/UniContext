## SPDX-License-Identifier: Apache-2.0
type
  Frontmatter* = object
    fields*: seq[(string, string)]

  Section* = object
    heading*: string
    level*: int
    content*: string

  KnowledgeNote* = object
    path*: string
    frontmatter*: Frontmatter
    title*: string
    sections*: seq[Section]

  SearchHit* = object
    noteId*: string
    path*: string
    heading*: string
    snippet*: string
    noteType*: string
    status*: string
    visibility*: string
    authority*: string
    updated*: string
    reviewAfter*: string
    rootName*: string
    content*: string
    rank*: int
    stale*: bool

  ContextSource* = object
    noteId*: string
    path*: string
    heading*: string
    authority*: string
    updated*: string
    stale*: bool

  GitState* = object
    requestedPath*: string
    root*: string
    branch*: string
    commit*: string
    status*: string
    diff*: string
    available*: bool
    truncated*: bool
    warning*: string

  ContextPacket* = object
    version*: int
    query*: string
    budgetTokens*: int
    estimatedTokens*: int
    rendered*: string
    git*: GitState
    sources*: seq[ContextSource]
    warnings*: seq[string]

const ContextPacketVersion* = 1

proc get*(frontmatter: Frontmatter; key: string): string =
  for field in frontmatter.fields:
    if field[0] == key:
      return field[1]

proc has*(frontmatter: Frontmatter; key: string): bool =
  frontmatter.get(key).len > 0
