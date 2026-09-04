# UniContext

UniContext compiles readable, version-controlled knowledge sources into short, sourced context
packets that can be reused by multiple agents.

Milestones K0 and K1 provide an end-to-end path: Markdown notes with flat YAML frontmatter,
section-aware parsing, a rebuildable SQLite FTS5 index, authority ranking, and budgeted context
packets. K2 exposes this path through an MCP stdio server.

```sh
nimble build
./unicontext index --manifest ../../knowledge-core/unicontext.toml
./unicontext context --manifest ../../knowledge-core/unicontext.toml \
  --query "memory authority" --budget 4000 --repository /path/to/worktree
./unicontext serve --manifest ../../knowledge-core/unicontext.toml
```

The project remains private during its initial release. It does not depend on Obsidian, a model,
or an agent. SQLite is a derived index; Markdown files remain the source of truth. Its generic
JSON-RPC and MCP lifecycle is supplied by the sibling UniMCP library, and its SQLite lifecycle is
supplied by the sibling UniDatabase library, both through local Nim paths.

See [docs/architecture.md](docs/architecture.md) for data flow, invariants, security boundaries,
and extraction gates. See [docs/validation.md](docs/validation.md) for current gate evidence and
known limitations. See [docs/extraction-assessment.md](docs/extraction-assessment.md) for the
evidence-based UniMCP, UniDatabase, and UniText boundaries.
The evidence used to admit the private UniText prototype and its remaining gates is defined in
[docs/unitext-entry-gate.md](docs/unitext-entry-gate.md).

## Current MCP tools

- `memory_search`: FTS5 search with metadata and provenance;
- `memory_get`: read a note by stable identifier;
- `memory_context`: compile a ranked and budgeted context packet;
- `memory_propose`: add a non-canonical proposal;
- `session_start`, `session_update`, and `session_close`: append immutable Markdown events.

Read tools are declared non-destructive and idempotent. Write tools never replace an existing
file and cannot write canonical memory directly.

`memory_context` accepts an optional `repository` path. UniContext invokes `git` directly with a
fixed read-only command set and adds the worktree root, branch, commit, short status, and bounded
unstaged diff before stored memory. Live Git output receives at most half of the packet budget.

## Current non-goals

- direct canonical-memory writes by an agent;
- embeddings or neural reranking;
- a graphical interface or a replacement for Maki, Crush, Claude Code, or Codex;
- repointing UniContext to UniText without an approved, fixture-backed migration;
- modification of existing UniMCP or UniDatabase consumers during the private prototype.
