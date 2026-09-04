# Validation status

This document records evidence for prototype gates. It does not declare a public release.

## K0 — Vertical prototype

Status: passed.

- Flat YAML frontmatter and section-aware Markdown parsing are tested.
- Canonical-note metadata and enum validation are tested.
- SQLite FTS5 indexing, provenance, exact identifier lookup, and punctuation-safe search are tested.
- The index is rebuildable from Markdown and rejects duplicate stable identifiers.

## K1 — Agent context

Status: passed for the current private corpus.

- Root visibility, authority, freshness, and context budgeting are tested.
- Live Git root, branch, commit, status, staged diff, and unstaged diff are collected read-only.
- Task text and Git output cannot exceed the rendered packet budget.
- Corpus fingerprinting detects added, removed, or changed Markdown files.
- Missing and stale indexes are reported explicitly.
- Proposals and session events are append-only and cannot cross configured roots through symlinks.

## K2 — Controlled MCP

Status: passed locally.

- Protocol revisions `2025-11-25`, `2025-06-18`, and `2024-11-05` are supported.
- Parse, invalid-request, initialization, method, and tool errors have deterministic JSON-RPC forms.
- Portable request/response and SQL fixtures are stored under `fixtures/`.
- A compiled server passes an inter-process stdio lifecycle and tool-call test.
- Maki 0.4.11 and Crush 0.76.0 completed model-driven `memory_search` calls against the release
  binary and returned `template.memory.decision`.
- Claude Code 2.1.236 reported the isolated server as connected.
- Codex CLI 0.149.0 completed a model-driven `memory_search` call against the release binary and
  returned `template.memory.decision`; this version required its experimental `mcp_2026_07_28`
  feature flag for MCP tools in `codex exec`.

## Storage contract

Current schema version: 2.

- `001-initial.sql` defines the FTS5 section index.
- `002-metadata.sql` defines index metadata and the corpus fingerprint.
- Rebuilds use an immediate transaction and roll back on any parse, validation, or duplicate-id
  failure.
- A database created by a newer schema version is rejected.

## Current limitations

- Validation has run on macOS arm64 only in this workspace.
- The Markdown parser intentionally supports a constrained subset; it is not a general CommonMark
  implementation.
- SQLite remains the only index backend.
- MCP stdio remains the only UniContext transport.
- Corpus freshness currently scans all included Markdown files for every read request; incremental
  manifests and filesystem watching remain future performance work.
- Search is lexical; embeddings and neural reranking remain out of scope.
- No public compatibility or migration promise exists before a versioned release.

## K3 — Library extraction

Status: passed for UniMCP and the SQLite-first UniDatabase boundary; UniText passed its independent
private prototype-entry gate.

Read-only inspection and stated future demand now provide the following evidence:

- UniMCP now owns the generic JSON-RPC/MCP stdio lifecycle. UniContext was repointed and all
  protocol, process, and client checks retained parity.
- UniDatabase now owns SQLite connection and statement lifecycles, binding, row access,
  transactions, schema-version primitives, and explicit capabilities. UniContext retains its own
  schema and migrations, and all storage and process checks retained parity.
- UniText now has equivalent Markdown, reStructuredText, RTF, and AsciiDoc fixtures, a neutral
  document model, stable identifiers, immutable text edits, loss-aware conversion, and versioned
  JSON interchange. No existing consumer was repointed.

See [extraction-assessment.md](extraction-assessment.md) for the evidence matrix, proposed boundaries,
and extraction order. No existing consumer was modified, and neither library was published.

Post-extraction validation used a release build linked through local sibling paths. The complete
UniContext, UniMCP, and UniDatabase suites passed; the knowledge index rebuilt as fresh; Maki and
Crush again returned `template.memory.decision` from model-driven calls; Claude Code reported the
release server as connected; and Codex completed the same tool call with its experimental MCP flag.
