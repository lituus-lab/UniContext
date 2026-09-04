CREATE VIRTUAL TABLE IF NOT EXISTS sections USING fts5(
  note_id UNINDEXED, path UNINDEXED, heading, content,
  note_type UNINDEXED, status UNINDEXED, visibility UNINDEXED,
  authority UNINDEXED, updated UNINDEXED, review_after UNINDEXED,
  root_name UNINDEXED, project UNINDEXED,
  tokenize='unicode61 remove_diacritics 2'
);
