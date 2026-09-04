# Architecture

## Purpose

UniContext is a context compiler. It does not own canonical knowledge, replace an agent, or train a
model. It turns human-readable, version-controlled notes and optional live repository state into a
small packet with explicit provenance.

## Data flow

```text
Markdown + flat YAML              optional Git worktree
          |                               |
          v                               v
section-aware parser             bounded read-only collector
          |                               |
          v                               |
rebuildable SQLite FTS5 index             |
          |                               |
          +---------------+---------------+
                          v
             authority and freshness ranker
                          |
                          v
                budgeted context packet
                          |
                   +------+------+
                   |             |
                  CLI         MCP stdio
```

## Sources of truth

Canonical Markdown and repository state are authoritative inputs. SQLite is a derived search
index and can always be deleted and rebuilt. Session events and agent proposals are append-only
Markdown, but remain lower-authority evidence until human promotion.

## Context packet contract

Version 1 contains:

- the exact task query and requested token budget;
- optional live Git root, branch, commit, short status, staged diff, and unstaged diff;
- ranked canonical sections with stable identifier, path, heading, authority, and update date;
- stale-memory, invalid-repository, and truncation warnings;
- an approximate token count based on four characters per token.

Live Git data receives at most half of the packet character budget. Remaining sections are added
in authority order only when their complete rendered block fits. A packet never silently cuts a
canonical section.

## Security boundaries

- MCP stdio reserves standard output for JSON-RPC messages.
- The server exposes no general shell or network capability.
- Git inspection invokes a fixed read-only command set through direct process arguments.
- Canonical roots and append-only write areas are fixed by the manifest.
- Existing proposal and session-event targets are never overwritten.
- Agent proposals never become canonical without human validation.

Repository inspection is explicit. A caller should not pass a private worktree to a remote model
unless sharing its status and diff with that model is acceptable.

## Internal prototype modules

- `text/markdown`: flat YAML frontmatter and Markdown sections;
- `database`: UniContext schemas, migrations, and FTS5 queries over UniDatabase;
- `index`: root traversal, validation, and index reconstruction;
- `workspace/manifest`: allowed roots and write areas;
- `workspace/git_state`: bounded live Git state;
- `context`: ranking, freshness, budgeting, and packet rendering;
- `memory`: append-only proposals and session events;
- `protocol`: UniContext tool definitions and handlers over UniMCP.

The UniContext modules remain application boundaries, not promises of public APIs.

## Extraction gates

UniMCP and the SQLite-first UniDatabase have been extracted as private sibling libraries and
UniContext consumes them through local Nim paths. Neither library depends on UniContext. UniText
remains uncreated until cross-format application fixtures define a shared document model and loss
contract. Persistent Markdown shapes, SQL behavior, JSON-RPC fixtures, and context packet fields
remain the portable contracts for a later Lituus implementation.
