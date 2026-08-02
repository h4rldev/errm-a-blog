CREATE TABLE guestbook_entries (
  id INTEGER PRIMARY KEY,
  username TEXT NOT NULL,
  content_markdown TEXT NOT NULL,
  posted_at INTEGER DEFAULT (strftime('%s', 'now')),
  last_edited_at INTEGER
);

CREATE INDEX idx_guestbook_entries_posted_at ON guestbook_entries(posted_at DESC);
CREATE INDEX idx_guestbook_entries_username ON guestbook_entries(username);
