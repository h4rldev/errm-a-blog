CREATE TABLE post_comments (
  id INTEGER PRIMARY KEY,
  parent_id INTEGER REFERENCES post_comments(id) ON DELETE CASCADE,
  post_id INTEGER NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  post_slug TEXT REFERENCES posts(slug) ON DELETE CASCADE,
  username TEXT NOT NULL,
  content_markdown TEXT NOT NULL,
  posted_at INTEGER DEFAULT (strftime('%s', 'now')),
  last_edited_at INTEGER
);

CREATE INDEX idx_post_comments_posted_at ON post_comments(posted_at DESC);
CREATE INDEX idx_post_comments_post_id ON post_comments(post_id);
CREATE INDEX idx_post_comments_post_slug ON post_comments(post_slug);
CREATE INDEX idx_post_comments_username ON post_comments(username);
