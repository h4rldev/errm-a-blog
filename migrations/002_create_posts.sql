CREATE TABLE posts (
  id INTEGER PRIMARY KEY,
  slug TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  summary TEXT,
  content_markdown TEXT NOT NULL,
  author_id TEXT NOT NULL REFERENCES users(uuid) ON DELETE CASCADE,
  tags TEXT NOT NULL DEFAULT '[]',
  posted_at INTEGER DEFAULT (strftime('%s', 'now')),
  edited_at INTEGER
);

CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_posts_posted_at ON posts(posted_at DESC);
CREATE INDEX idx_posts_slug ON posts(slug);
