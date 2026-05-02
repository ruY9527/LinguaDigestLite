-- LinguaDigestLite SQLite Schema
-- Version: 1
-- Description: Local database schema for RSS feed reader app

PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

-- ============================================================
-- Application metadata (migration version tracking)
-- ============================================================
CREATE TABLE IF NOT EXISTS app_meta (
    key TEXT PRIMARY KEY,
    value TEXT
);

-- ============================================================
-- RSS Feeds
-- ============================================================
CREATE TABLE IF NOT EXISTS feeds (
    id TEXT PRIMARY KEY,                  -- UUID string
    title TEXT NOT NULL,
    link TEXT,
    feedUrl TEXT NOT NULL UNIQUE,
    description TEXT,
    notes TEXT,                           -- User custom notes
    imageUrl TEXT,
    lastUpdated REAL,                     -- Unix timestamp
    isActive INTEGER DEFAULT 1,           -- 1=active, 0=disabled
    isBuiltIn INTEGER DEFAULT 0,          -- 1=built-in feed, 0=user-added
    createdAt REAL,                       -- Unix timestamp
    updateInterval INTEGER DEFAULT 60,    -- Refresh interval in minutes
    etag TEXT,                            -- ETag from last HTTP response
    lastModified TEXT,                    -- Last-Modified header value
    lastRefreshTime REAL,                 -- Actual last refresh timestamp
    consecutiveErrors INTEGER DEFAULT 0   -- Consecutive refresh failure count
);

-- ============================================================
-- Articles
-- ============================================================
CREATE TABLE IF NOT EXISTS articles (
    id TEXT PRIMARY KEY,                  -- UUID string
    feedId TEXT,                          -- FK to feeds.id
    title TEXT NOT NULL,
    link TEXT NOT NULL,                   -- Article URL
    author TEXT,
    summary TEXT,                         -- Short summary/preview
    content TEXT,                         -- Full article content
    htmlContent TEXT,                     -- Raw HTML content
    imageUrl TEXT,
    publishedAt REAL,                     -- Original publish date (Unix timestamp)
    fetchedAt REAL NOT NULL,              -- When article was fetched (Unix timestamp)
    isRead INTEGER DEFAULT 0,            -- 1=read, 0=unread
    isFavorite INTEGER DEFAULT 0,        -- 1=favorited, 0=not
    readingProgress REAL DEFAULT 0.0,    -- 0.0 to 1.0
    FOREIGN KEY (feedId) REFERENCES feeds(id)
);

-- Unique index: same article URL in same feed = duplicate
CREATE UNIQUE INDEX IF NOT EXISTS idx_articles_link_feed
    ON articles(link, feedId);

-- Query optimization indexes
CREATE INDEX IF NOT EXISTS idx_articles_feedId ON articles(feedId);
CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(publishedAt);
CREATE INDEX IF NOT EXISTS idx_articles_favorite ON articles(isFavorite);
CREATE INDEX IF NOT EXISTS idx_articles_read ON articles(isRead);

-- ============================================================
-- Vocabulary (words saved by user)
-- ============================================================
CREATE TABLE IF NOT EXISTS vocabulary (
    id TEXT PRIMARY KEY,                  -- UUID string
    word TEXT NOT NULL,                   -- Lowercased word
    definition TEXT,                      -- Chinese definition
    phonetic TEXT,                        -- IPA phonetic notation
    partOfSpeech TEXT,                    -- e.g., noun, verb, adj
    contextSnippet TEXT,                  -- Original context from article
    exampleSentence TEXT,
    articleId TEXT,                       -- FK to articles.id (optional)
    categoryId TEXT,                      -- FK to categories.id (optional)
    englishDefinition TEXT,               -- English definition (from ECDICT)
    groupedDefinitions TEXT,              -- JSON: [{pos, definitions}]
    masteredLevel INTEGER DEFAULT 0,     -- 0-5 mastery level (SM-2)
    nextReviewDate REAL,                  -- Next SRS review date (Unix timestamp)
    addedAt REAL NOT NULL,                -- When word was added (Unix timestamp)
    lastReviewedAt REAL,                  -- Last review timestamp
    reviewCount INTEGER DEFAULT 0,       -- Total review count
    easeFactor REAL DEFAULT 2.5,         -- SM-2 ease factor
    interval INTEGER DEFAULT 0           -- SM-2 interval in days
);

CREATE INDEX IF NOT EXISTS idx_vocab_word ON vocabulary(word);
CREATE INDEX IF NOT EXISTS idx_vocab_category ON vocabulary(categoryId);
CREATE INDEX IF NOT EXISTS idx_vocab_review ON vocabulary(nextReviewDate);

-- ============================================================
-- Vocabulary Categories
-- ============================================================
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,                  -- UUID string
    name TEXT NOT NULL,
    description TEXT,
    color TEXT DEFAULT '#007AFF',         -- Hex color code
    icon TEXT DEFAULT 'folder',           -- SF Symbol name
    createdAt REAL,                       -- Unix timestamp
    isDefault INTEGER DEFAULT 0,         -- 1=default category, 0=user-created
    "order" INTEGER DEFAULT 0            -- Display order
);

-- ============================================================
-- Refresh Logs
-- ============================================================
CREATE TABLE IF NOT EXISTS refresh_logs (
    id TEXT PRIMARY KEY,                  -- UUID string
    feedId TEXT NOT NULL,                 -- FK to feeds.id
    feedTitle TEXT NOT NULL,              -- Denormalized for display
    isSuccess INTEGER NOT NULL,           -- 1=success, 0=failure
    errorMessage TEXT,
    statusCode INTEGER,                   -- HTTP status code if applicable
    addedCount INTEGER DEFAULT 0,        -- Number of new articles added
    timestamp REAL NOT NULL               -- When refresh occurred (Unix timestamp)
);

CREATE INDEX IF NOT EXISTS idx_logs_feedId ON refresh_logs(feedId);
CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON refresh_logs(timestamp);

-- ============================================================
-- Article Cleanup Queries (reference)
-- ============================================================
-- Delete read articles older than 30 days (except favorites):
-- DELETE FROM articles WHERE isFavorite = 0 AND isRead = 1
--   AND publishedAt IS NOT NULL AND publishedAt < strftime('%s', 'now', '-30 days');
--
-- Delete unread articles older than 7 days (except favorites):
-- DELETE FROM articles WHERE isFavorite = 0 AND isRead = 0
--   AND publishedAt IS NOT NULL AND publishedAt < strftime('%s', 'now', '-7 days');
--
-- Trim refresh logs to last 300:
-- DELETE FROM refresh_logs WHERE id NOT IN (
--   SELECT id FROM refresh_logs ORDER BY timestamp DESC LIMIT 300
-- );
