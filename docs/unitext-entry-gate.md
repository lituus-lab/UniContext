# UniText entry gate

UniText passed its repository-entry gate and reached private 1.0.0 as a Nim library. Two concrete consumers
establish demand:

- a Pandoc-like document converter;
- an office-style text application with TUI, web, and desktop interfaces.

The first representative fixtures and operations now validate the library boundary; later gates
remain deliberately narrower than full format compatibility.

## Family analogy

UniText should occupy the same architectural role for structured documents that UniMusicIO
occupies for musical data:

- detect and inspect formats;
- parse external representations into a stable domain model;
- serialize that model into supported formats;
- convert through the model rather than through pairwise format translators;
- preserve format-specific round-trip information when requested;
- report unsupported constructs and lossy transformations explicitly;
- expose streaming and bounded resource behavior where formats permit it.

The Pandoc-like converter is a CLI application built on UniText. The office-style product is a
separate application family built on UniText. Its TUI, web, desktop, layout, rendering, input,
clipboard, collaboration, persistence, and workspace concerns do not belong in UniText.

For each first application, record the following before implementation:

- input formats and representative private fixtures;
- required operations: parse, inspect, transform, render, convert, diff, or round-trip;
- structural objects that must survive: headings, paragraphs, lists, tables, links, images,
  directives, styles, fields, footnotes, and embedded raw content;
- whether source positions and original spelling must be retained;
- accepted normalization and explicitly tolerated data loss;
- malformed-input behavior, resource limits, and external-reference policy;
- streaming, random-access, and memory requirements;
- target outputs and round-trip expectations.

The consumer-count and initial fixture gates are satisfied. The prototype includes equivalent
Markdown, reStructuredText, AsciiDoc, and styled RTF documents, a normalized semantic snapshot,
immutable edit operations, conversion loss diagnostics, malformed-input cases, and a versioned
JSON interchange. Subsequent compatibility gates still require broader representative fixtures:

- the converter must exercise bidirectional conversion, normalization, and explicit loss reports;
- the office application must exercise editable document state, selections, formatting, undoable
  operations, layout-independent structure, and concurrent frontend projections;
- both consumers must agree on which semantic structures belong in the neutral document model and
  which presentation details remain format- or frontend-specific.

Golden input, normalized-tree, output, edit-operation, loss-report, and malformed-input fixtures
must be reviewable without either application.

The initial neutral model should be derived from those fixtures. It should separate:

- semantic document structure;
- source-format syntax and round-trip metadata;
- immutable document values and explicit edit operations;
- frontend selections, cursors, view state, and layout;
- conversion diagnostics and data-loss records.

As with UniMusicIO, format adapters may retain specialized metadata without polluting the neutral
model. Unsupported format features must survive as explicit extensions or loss records, never as
silently discarded content.

The 1.0.0 surface adds immutable structural edits, a stable C ABI, a Cython binding, executable
documentation, and validated binary and source packages. These release surfaces do not broaden the
document-format subset described above.

The current UniContext Markdown reader remains application code. UniContext has not been repointed
to UniText because its frontmatter-aware note contract is narrower and no migration has been
approved.
