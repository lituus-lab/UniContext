# UniContext

UniContext compiles readable, version-controlled knowledge sources into short, sourced context
packets. Markdown notes and their Git history are canonical; the SQLite index is derived and can
be deleted and rebuilt at any time.

It does not depend on a model, an agent, or a note-taking application.

## Surfaces

- **Nim library** — `import UniContext`.
- **Command** — `unicontext index | search | context | status | serve`.
- **MCP server** — `unicontext serve` speaks JSON-RPC over stdio.
- **C ABI** — `libUniContext.a` / `.so` / `.dylib` and `include/UniContext.h`.
- **Python** — `pip install lituus-unicontext`, a Cython binding over the C ABI.

## Module map

| Layer | What it holds |
|---|---|
| `domain` | the types every other layer speaks in |
| `workspace` | the manifest of allowed roots, and bounded live Git state |
| `text` | flat YAML frontmatter and section-aware Markdown parsing |
| `database` | schema, migrations and FTS5 queries over UniDatabase |
| `context` | ranking, freshness, budgeting and packet rendering |
| `memory` | append-only proposals and session events |
| `index` | root traversal, validation and index reconstruction |
| `protocol` | the MCP tool definitions and handlers, over UniMCP |

The order is enforced, not documented: `vgraph.cfg` lists it and `nimble checkVGraph` fails an
import that climbs it.

## Uni-family relationship

- [UniMCP](https://github.com/lituus-lab/UniMCP) supplies the JSON-RPC and MCP lifecycle.
- [UniDatabase](https://github.com/lituus-lab/UniDatabase) supplies the SQLite lifecycle.

Neither depends on UniContext, and each reaches it through exactly one module, which `vgraph.cfg`
records and the gate enforces.

## Nim example

```nim
import UniContext

let hits = @[
  SearchHit(noteId: "decision.storage", path: "decision.storage.md",
    heading: "Storage", content: "Markdown is canonical; the index is derived.",
    status: "accepted", authority: "maintainer", updated: "2026-07-15"),
  SearchHit(noteId: "draft.retrieval", path: "draft.retrieval.md",
    heading: "Retrieval", content: "Half-written.",
    status: "draft", authority: "maintainer", updated: "2026-07-15")]

# The draft is filtered out, and `rank` is derived from authority and status
# rather than read from the hit.
let packet = buildContextPacket("how is context assembled?", hits, 1024)
echo packet.sources.len          # 1
echo packet.sources[0].noteId    # decision.storage
echo packet.estimatedTokens <= packet.budgetTokens  # true
```

`examples/demo.nim` runs the same path with a stale memory and a budget too small for every hit.

## Command

The command is built by its own task rather than installed by `nimble
install`: declaring a binary makes install build it from a copied tree where
nimble cannot resolve the engines this library imports.

```sh
nimble cli
./build/unicontext index   --manifest /absolute/path/to/unicontext.toml
./build/unicontext context --manifest /absolute/path/to/unicontext.toml \
  --query "memory authority" --budget 4000 --repository /path/to/worktree
./build/unicontext serve   --manifest /absolute/path/to/unicontext.toml
```

See [docs/integration.md](docs/integration.md) for the MCP client declaration and the clients it
has been checked against, and [docs/architecture.md](docs/architecture.md) for data flow,
invariants and security boundaries.

## MCP tools

- `memory_search` — FTS5 search with metadata and provenance;
- `memory_get` — read a note by stable identifier;
- `memory_context` — compile a ranked, budgeted context packet;
- `memory_propose` — add a non-canonical proposal;
- `session_start`, `session_update`, `session_close` — append immutable Markdown events.

Read tools are declared non-destructive and idempotent. Write tools never replace an existing file
and cannot write canonical memory directly.

`memory_context` accepts an optional `repository` path. UniContext then invokes `git` with a fixed
read-only command set and adds the worktree root, branch, commit, short status and a bounded
unstaged diff. Live Git output receives at most half the packet budget. A caller should not pass a
private worktree to a remote model unless sharing its status and diff is acceptable.

## Non-goals

- direct canonical-memory writes by an agent;
- embeddings or neural reranking;
- a graphical interface.

## Gates

```sh
nimble testAll     # Nim debug + release + C ABI
nimble pyTest      # Cython extension + pytest
nimble ctest       # the C header linked against the built library
nimble lint        # nimpretty
nimble checkVGraph # layer directions and engine confinement
nimble coverage    # gcov + lcov
nimble docs        # nimib book + API reference into pages/
```

Every task runs through `tools/gate.nim`: nimble exits 0 on a task whose `exec` failed, so its
exit code proves nothing and the task's own success marker is what the gate reads.

## Licence

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
