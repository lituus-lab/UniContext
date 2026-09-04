## SPDX-License-Identifier: Apache-2.0
import std/[sets, strutils]
import UniDatabase/sqlite
import UniContext/domain/types

type
  StoreError* = object of IOError
  Store* = object
    connection: Connection

const
  SchemaVersion* = 2
  SchemaSql* = """CREATE VIRTUAL TABLE IF NOT EXISTS sections USING fts5(
  note_id UNINDEXED, path UNINDEXED, heading, content,
  note_type UNINDEXED, status UNINDEXED, visibility UNINDEXED,
  authority UNINDEXED, updated UNINDEXED, review_after UNINDEXED,
  root_name UNINDEXED, project UNINDEXED,
  tokenize='unicode61 remove_diacritics 2'
);"""
  MetadataSchemaSql* = """CREATE TABLE IF NOT EXISTS metadata(
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
);"""

proc openStore*(path: string): Store = result.connection = openSqlite(path)
proc close*(store: var Store) = store.connection.close
proc execute(store: Store; sql: string) = store.connection.execute(sql)
proc schemaVersion*(store: Store): int = store.connection.schemaVersion

proc initialize*(store: Store) =
  store.execute("PRAGMA journal_mode=WAL;")
  let version = store.schemaVersion
  if version > SchemaVersion:
    raise newException(StoreError, "database schema is newer than this UniContext build: " &
      $version & " > " & $SchemaVersion)
  if version < 1:
    store.execute(SchemaSql)
    store.connection.setSchemaVersion(1)
  if version < 2:
    store.execute(MetadataSchemaSql)
    store.connection.setSchemaVersion(2)

proc beginTransaction*(store: Store) = store.connection.beginImmediate
proc commit*(store: Store) = store.connection.commit
proc rollback*(store: Store) = store.connection.rollback

proc setMetadata*(store: Store; key, value: string) =
  var statement = store.connection.prepare(
    "INSERT OR REPLACE INTO metadata(key,value) VALUES(?,?)")
  defer: statement.finalize
  statement.bindText(1, key)
  statement.bindText(2, value)
  if statement.step != statementDone:
    raise newException(StoreError, "writing metadata returned a row")

proc getMetadata*(store: Store; key: string): string =
  var statement = store.connection.prepare("SELECT value FROM metadata WHERE key = ?")
  defer: statement.finalize
  statement.bindText(1, key)
  if statement.step == rowAvailable: result = statement.columnText(0)

proc clear*(store: Store) = store.execute("DELETE FROM sections;")

proc recreate*(store: Store) =
  store.execute("DROP TABLE IF EXISTS sections;")
  store.initialize

proc add*(store: Store; note: KnowledgeNote; rootName: string) =
  const sql = """
    INSERT INTO sections(note_id,path,heading,content,note_type,status,visibility,authority,updated,
                         review_after,root_name,project)
    VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
  """
  var statement = store.connection.prepare(sql)
  defer: statement.finalize
  for section in note.sections:
    statement.bindText(1, note.frontmatter.get("id"))
    statement.bindText(2, note.path)
    statement.bindText(3, section.heading)
    statement.bindText(4, section.content)
    statement.bindText(5, note.frontmatter.get("type"))
    statement.bindText(6, note.frontmatter.get("status"))
    statement.bindText(7, note.frontmatter.get("visibility"))
    statement.bindText(8, note.frontmatter.get("authority"))
    statement.bindText(9, note.frontmatter.get("updated"))
    statement.bindText(10, note.frontmatter.get("review_after"))
    statement.bindText(11, rootName)
    statement.bindText(12, note.frontmatter.get("project"))
    if statement.step != statementDone:
      raise newException(StoreError, "inserting a section returned a row")
    statement.reset
    statement.clearBindings

proc getNote*(store: Store; noteId: string): seq[SearchHit]

proc compileFtsQuery(query: string): string =
  var token: string
  var tokens: seq[string]
  proc flushToken() =
    if token.len > 0:
      tokens.add("\"" & token & "\"")
      token.setLen(0)
  for character in query:
    if character in {'a'..'z', 'A'..'Z', '0'..'9', '_', '-'}: token.add(character)
    else: flushToken()
  flushToken()
  result = tokens.join(" OR ")

proc search*(store: Store; query: string; limit = 10): seq[SearchHit] =
  if query.strip.len == 0 or limit <= 0: return
  var seen = initHashSet[string]()
  for hit in store.getNote(query.strip):
    if result.len >= limit: return
    let key = hit.noteId & "\x1f" & hit.heading
    seen.incl(key)
    result.add(hit)
  let ftsQuery = compileFtsQuery(query)
  if ftsQuery.len == 0: return
  const sql = """
    SELECT note_id,path,heading,snippet(sections,3,'[',']',' … ',18),
           note_type,status,visibility,authority,updated,review_after,root_name,content
    FROM sections WHERE sections MATCH ? ORDER BY bm25(sections) LIMIT ?
  """
  var statement = store.connection.prepare(sql)
  defer: statement.finalize
  statement.bindText(1, ftsQuery)
  statement.bindInt64(2, (limit * 2).int64)
  while statement.step == rowAvailable:
    let hit = SearchHit(
      noteId: statement.columnText(0), path: statement.columnText(1),
      heading: statement.columnText(2), snippet: statement.columnText(3),
      noteType: statement.columnText(4), status: statement.columnText(5),
      visibility: statement.columnText(6), authority: statement.columnText(7),
      updated: statement.columnText(8), reviewAfter: statement.columnText(9),
      rootName: statement.columnText(10), content: statement.columnText(11))
    let key = hit.noteId & "\x1f" & hit.heading
    if key notin seen:
      seen.incl(key)
      result.add(hit)
      if result.len >= limit: break

proc getNote*(store: Store; noteId: string): seq[SearchHit] =
  const sql = """
    SELECT note_id,path,heading,content,note_type,status,visibility,authority,updated,
           review_after,root_name,content
    FROM sections WHERE note_id = ? ORDER BY rowid
  """
  var statement = store.connection.prepare(sql)
  defer: statement.finalize
  statement.bindText(1, noteId)
  while statement.step == rowAvailable:
    result.add(SearchHit(
      noteId: statement.columnText(0), path: statement.columnText(1),
      heading: statement.columnText(2), snippet: statement.columnText(3),
      noteType: statement.columnText(4), status: statement.columnText(5),
      visibility: statement.columnText(6), authority: statement.columnText(7),
      updated: statement.columnText(8), reviewAfter: statement.columnText(9),
      rootName: statement.columnText(10), content: statement.columnText(11)))
