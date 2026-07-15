CREATE TABLE users {
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT CHECK(role IN ('poster', 'administrator')) NOT NULL,
  created_at INTEGER DEFAULT (strftime('%s', 'now'))
};
