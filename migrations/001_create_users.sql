CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  uuid TEXT UNIQUE NOT NULL, /* Never updated */
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK(role IN ('poster', 'administrator', 'super-administrator')) NOT NULL,
  auth_version INTEGER NOT NULL DEFAULT 1,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER /* Only updated on name or password change */
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_uuid ON users(uuid);
