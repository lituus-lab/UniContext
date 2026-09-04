<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0005: Markdown and Git are the source of truth

- Status: Accepted
- Date: 2026-07-15
- Scope: UniContext's index, memory and context packets

## Decision

Markdown notes and their Git history are canonical. The SQLite database is a
derived index: it may be deleted at any time and rebuilt from the notes.

Nothing in the index overrides the working tree. When the two disagree, the
notes win and the index is stale, never the other way round.

## Consequences

- `rebuildIndex` is a full reprojection, not a migration, and runs in one
  transaction: a failed rebuild rolls back to the previous index rather than
  leaving a half-written one.
- A context packet records the Git state it was built from, so a reader can
  tell a packet built from a dirty tree from one built from a commit.
- The index carries no user-authored data, so it is not backed up and not
  part of the repository.
- The cost is a rebuild whenever the notes move ahead of the index; the
  benefit is that no divergence can become permanent.
