CREATE TABLE blocked_words (
  scope TEXT PRIMARY KEY,
  enforced_by TEXT NOT NULL,
  patterns TEXT NOT NULL DEFAULT '[]',
  keywords TEXT NOT NULL DEFAULT '[]',
  updated_at INTEGER
);

INSERT OR IGNORE INTO blocked_words (scope, enforced_by) VALUES ('comments','system'),('guestbook','system'),('global','system');
