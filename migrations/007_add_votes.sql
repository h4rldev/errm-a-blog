ALTER TABLE post_comments ADD COLUMN votes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE guestbook_entries ADD COLUMN votes INTEGER NOT NULL DEFAULT 0;

CREATE TABLE comment_votes (
  comment_id INTEGER NOT NULL,
  ip TEXT NOT NULL,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  PRIMARY KEY (comment_id, ip)
);

CREATE TABLE guestbook_votes (
  entry_id INTEGER NOT NULL,
  ip TEXT NOT NULL,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  PRIMARY KEY (entry_id, ip)
);
