# Library extraction assessment

This assessment separates three kinds of evidence:

- implemented evidence: behavior already exercised by UniContext fixtures and tests;
- observed evidence: read-only inspection of another local codebase;
- demand evidence: an explicitly identified future consumer.

It does not authorize edits to an existing consumer or creation of a new repository.

## UniMCP

Readiness: extracted privately; UniContext parity passed.

Implemented evidence:

- UniContext implements JSON-RPC 2.0 validation, MCP initialization negotiation, notifications,
  tool discovery, tool calls, structured results, and stdio framing.
- Portable protocol fixtures and an inter-process test define observable behavior.

Observed evidence:

- `llm/agent-nim/src/mcp.nim` contains an independent Nim MCP server and client.
- `apps/omniforge-go/packages/nim/search.nim` contains an independent Nim MCP stdio plugin template.
- `apps/omniforge-go/pkg/mcp` provides an independent Go implementation that can remain a protocol
  oracle during extraction.

Demand evidence:

- UniContext is a server consumer.
- UniMusic is expected to consume or expose MCP capabilities.
- A future UniForge derived from OmniForge is expected to consume MCP capabilities.
- UniGeom and other applications may be exposed through MCP clients or servers.

Proposed first boundary:

- JSON-RPC request identifiers, success responses, and standard errors;
- newline-delimited stdio transport;
- MCP initialization state and protocol negotiation;
- tool descriptors, input schemas, annotations, calls, and results;
- a server dispatcher with application-provided tool handlers;
- a subprocess client with explicit lifecycle and timeouts.

The library must not contain memory, vault, agent, model, or UniContext concepts. HTTP transports,
resources, prompts, sampling, elicitation, and authorization remain later capabilities unless a real
consumer requires them.

## UniDatabase

Readiness: SQLite-first core extracted privately; UniContext parity passed.

Implemented evidence:

- UniContext uses a minimal SQLite C binding, prepared statements, FTS5, transactions, WAL mode,
  schema versions, migrations, and metadata.
- Migration, rollback, future-version rejection, FTS query safety, and reconstruction are tested.

Observed evidence:

- `llm/agent-nim/src/memory_sqlite.nim` independently implements SQLite, FTS5, prepared statements,
  triggers, WAL, and application-specific schemas.
- `lituus-lab/UniDAV/src/UniDAV/sqlite_store.nim` independently implements versioned migrations and
  transactions.
- UniMedia uses SQLite through `db_connector` for domain storage.

Demand evidence:

- UniGeom is an identified consumer.
- UniContext needs SQLite FTS5 and metadata today.
- PostgreSQL and DuckDB are planned capabilities for later consumers.

Proposed first boundary:

- owned connection and statement lifecycles;
- typed bind and column access;
- explicit transactions and rollback;
- schema version inspection and ordered migrations;
- backend capability discovery;
- SQLite-specific WAL, FTS5, and pragma capabilities.

PostgreSQL and DuckDB must be modeled as capability-bearing backends after concrete consumers exist.
They must not be simulated behind an API that only exposes SQLite's intersection with them.

## UniText

Readiness: private 1.0.0 library locally validated; consumer integration remains gated.

Architectural role: structured-document I/O engine analogous to UniMusicIO, not an editor toolkit
or user-interface framework.

Implemented evidence:

- UniContext implements a deliberately constrained Markdown and flat YAML-frontmatter reader.
- Its tests define duplicate-key handling, scalar decoding, metadata validation, and fenced-heading
  behavior.
- The sibling UniText 1.0.0 library defines a bounded semantic tree, stable node identifiers,
  immutable text edits, format detection, explicit loss diagnostics, and a versioned JSON
  interchange.
- Equivalent Markdown, reStructuredText, AsciiDoc, and styled RTF fixtures pass block-level
  semantic parity. The three lightweight markup codecs also preserve strong, emphasis,
  inline-code, and hyperlink semantics.

Observed evidence:

- `llm/agent-nim/src/yaml_frontmatter.nim` is an independent structured-text consumer, but it mostly
  overlaps UniContext's Markdown-frontmatter use case.
- No existing application has yet consumed the shared model; those trees remain unchanged pending
  explicit approval.

Demand evidence:

- A Pandoc-like converter requires multi-format parsing, normalization, conversion, and explicit
  loss reporting.
- An office-style text application targeting TUI, web, and desktop requires a stable editable
  document model separated from frontend view state and layout.

The consumer-count, extraction, and private 1.0.0 gates are satisfied. The stable surface includes
immutable text and structural edits, a C ABI, Python binding, Book, documentation, packaging, and
local quality gates. Broader documents, source maps, format-specific round-trip metadata, and rich
RTF remain future versioned capabilities. The current subset must not be advertised as complete
format compatibility.

## Recommended order

1. UniContext K2 fixtures were frozen and passed.
2. UniMCP was extracted and UniContext was repointed with parity.
3. The SQLite-first UniDatabase core was extracted and UniContext was repointed with parity.
4. UniText reached private 1.0.0 from cross-format fixtures without repointing existing consumers.
5. Expand UniText only through fixture-backed semantic and round-trip gates.

Each extraction requires behavioral parity, no reverse dependency on UniContext, no modification of
an existing consumer without explicit approval, and an independently reviewable branch.
