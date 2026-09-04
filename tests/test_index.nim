## SPDX-License-Identifier: Apache-2.0
import std/[os, strutils, times, unittest]
import UniDatabase/sqlite
import UniContext/[database/store, index/indexer]
import UniContext/text/markdown

proc createDatabaseAtVersion(path: string; version: int; schema = "") =
  var connection = openSqlite(path)
  if schema.len > 0: connection.execute(schema)
  connection.setSchemaVersion(version)
  connection.close

suite "Index SQLite FTS5":
  test "keeps the portable SQL fixture identical to the runtime schema":
    let fixture = currentSourcePath.parentDir.parentDir / "fixtures" / "sql" / "001-initial.sql"
    check readFile(fixture).strip == SchemaSql.strip
    let metadataFixture = currentSourcePath.parentDir.parentDir / "fixtures" /
        "sql" /
      "002-metadata.sql"
    check readFile(metadataFixture).strip == MetadataSchemaSql.strip

  test "migrates schema version one and rejects future schemas":
    let base = getTempDir() / ("unicontext-schema-" & $getTime().toUnix)
    createDir(base)
    let legacyPath = base / "legacy.sqlite"
    createDatabaseAtVersion(legacyPath, 1, SchemaSql)
    var legacy = openStore(legacyPath)
    legacy.initialize
    check legacy.schemaVersion == SchemaVersion
    legacy.setMetadata("migration", "complete")
    check legacy.getMetadata("migration") == "complete"
    legacy.close

    let futurePath = base / "future.sqlite"
    createDatabaseAtVersion(futurePath, SchemaVersion + 1)
    var future = openStore(futurePath)
    expect StoreError:
      future.initialize
    future.close

    for path in [legacyPath, futurePath]:
      removeFile(path)
      for suffix in ["-wal", "-shm"]:
        let sidecar = path & suffix
        if fileExists(sidecar): removeFile(sidecar)
    removeDir(base)

  test "indexes and retrieves a section with provenance":
    let base = getTempDir() / ("unicontext-test-" & $getTime().toUnix)
    createDir(base)
    let notePath = base / "note.md"
    let dbPath = base / "index.sqlite"
    writeFile(notePath, """---
id: lesson.context.authority
type: lesson
status: accepted
visibility: private
authority: test
updated: 2026-08-21
---
# Context authority

Current code and reproducible tests take precedence over old memory.
""")
    let report = rebuildIndex(base, dbPath)
    check report.documents == 1
    var database = openStore(dbPath)
    database.initialize
    check database.schemaVersion == SchemaVersion
    let hits = database.search("reproducible")
    check hits.len == 1
    check hits[0].noteId == "lesson.context.authority"
    check hits[0].authority == "test"
    let byIdentifier = database.search("lesson.context.authority")
    check byIdentifier.len == 1
    check byIdentifier[0].heading == "Context authority"
    check database.search("\" unmatched ( punctuation").len == 0
    database.close
    removeFile(notePath)
    removeFile(dbPath)
    let wal = dbPath & "-wal"
    let shm = dbPath & "-shm"
    if fileExists(wal): removeFile(wal)
    if fileExists(shm): removeFile(shm)
    removeDir(base)

  test "rolls back a failed rebuild and rejects duplicate identifiers":
    let base = getTempDir() / ("unicontext-index-rollback-" & $getTime().toUnix)
    createDir(base)
    let firstPath = base / "first.md"
    let duplicatePath = base / "duplicate.md"
    let dbPath = base / "index.sqlite"
    writeFile(firstPath, """---
id: decision.unique
type: decision
status: accepted
visibility: private
authority: maintainer
updated: 2026-08-21
---
# Unique decision

Durable indexed content.
""")
    discard rebuildIndex(base, dbPath)
    writeFile(duplicatePath, """---
id: decision.unique
type: decision
status: accepted
visibility: private
authority: maintainer
updated: 2026-08-21
---
# Duplicate decision

This rebuild must fail atomically.
""")
    expect MarkdownError:
      discard rebuildIndex(base, dbPath)

    var database = openStore(dbPath)
    database.initialize
    let hits = database.search("durable")
    check hits.len == 1
    check hits[0].noteId == "decision.unique"
    database.close

    removeFile(firstPath)
    removeFile(duplicatePath)
    removeFile(dbPath)
    for suffix in ["-wal", "-shm"]:
      let sidecar = dbPath & suffix
      if fileExists(sidecar): removeFile(sidecar)
    removeDir(base)
