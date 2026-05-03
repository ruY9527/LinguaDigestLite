import Foundation

/// 数据库管理器 - 使用SQLite本地存储
class DatabaseManager {
    static let shared = DatabaseManager()

    var db: SQLiteHelper?
    let dbPath: String
    let articleQueue = DispatchQueue(label: "com.linguadigest.articleQueue")

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("LinguaDigestLite")
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        dbPath = appDir.appendingPathComponent("linguadigest.sqlite").path

        do {
            db = try SQLiteHelper(path: dbPath)
            try createTables()
            ensureVocabularyCategoryIdsColumn()
            try migrateFromUserDefaults()
            syncBuiltInFeeds()
            sanitizeLiteralNilValues()
            initializeCategories()
        } catch {
            print("❌ DatabaseManager init failed: \(error)")
        }
    }

    // MARK: - Table Creation

    private func createTables() throws {
        try db?.execute("""
            CREATE TABLE IF NOT EXISTS feeds (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                link TEXT,
                feedUrl TEXT NOT NULL UNIQUE,
                description TEXT,
                notes TEXT,
                imageUrl TEXT,
                lastUpdated REAL,
                isActive INTEGER DEFAULT 1,
                isBuiltIn INTEGER DEFAULT 0,
                createdAt REAL,
                updateInterval INTEGER DEFAULT 60,
                etag TEXT,
                lastModified TEXT,
                lastRefreshTime REAL,
                consecutiveErrors INTEGER DEFAULT 0
            )
        """)

        try db?.execute("""
            CREATE TABLE IF NOT EXISTS articles (
                id TEXT PRIMARY KEY,
                feedId TEXT,
                title TEXT NOT NULL,
                link TEXT NOT NULL,
                author TEXT,
                summary TEXT,
                content TEXT,
                htmlContent TEXT,
                imageUrl TEXT,
                publishedAt REAL,
                fetchedAt REAL NOT NULL,
                isRead INTEGER DEFAULT 0,
                isFavorite INTEGER DEFAULT 0,
                readingProgress REAL DEFAULT 0.0,
                FOREIGN KEY (feedId) REFERENCES feeds(id)
            )
        """)

        try db?.execute("""
            CREATE UNIQUE INDEX IF NOT EXISTS idx_articles_link_feed
            ON articles(link, feedId)
        """)

        try db?.execute("""
            CREATE INDEX IF NOT EXISTS idx_articles_feedId ON articles(feedId)
        """)

        try db?.execute("""
            CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(publishedAt)
        """)

        try db?.execute("""
            CREATE TABLE IF NOT EXISTS vocabulary (
                id TEXT PRIMARY KEY,
                word TEXT NOT NULL,
                definition TEXT,
                phonetic TEXT,
                partOfSpeech TEXT,
                contextSnippet TEXT,
                exampleSentence TEXT,
                articleId TEXT,
                categoryId TEXT,
                categoryIds TEXT,
                englishDefinition TEXT,
                groupedDefinitions TEXT,
                masteredLevel INTEGER DEFAULT 0,
                nextReviewDate REAL,
                addedAt REAL NOT NULL,
                lastReviewedAt REAL,
                reviewCount INTEGER DEFAULT 0,
                easeFactor REAL DEFAULT 2.5,
                interval INTEGER DEFAULT 0
            )
        """)

        try db?.execute("""
            CREATE INDEX IF NOT EXISTS idx_vocab_word ON vocabulary(word)
        """)

        try db?.execute("""
            CREATE INDEX IF NOT EXISTS idx_vocab_category ON vocabulary(categoryId)
        """)

        try db?.execute("""
            CREATE TABLE IF NOT EXISTS categories (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                description TEXT,
                color TEXT DEFAULT '#007AFF',
                icon TEXT DEFAULT 'folder',
                createdAt REAL,
                isDefault INTEGER DEFAULT 0,
                "order" INTEGER DEFAULT 0
            )
        """)

        try db?.execute("""
            CREATE TABLE IF NOT EXISTS refresh_logs (
                id TEXT PRIMARY KEY,
                feedId TEXT NOT NULL,
                feedTitle TEXT NOT NULL,
                isSuccess INTEGER NOT NULL,
                errorMessage TEXT,
                statusCode INTEGER,
                addedCount INTEGER DEFAULT 0,
                timestamp REAL NOT NULL
            )
        """)

        try db?.execute("""
            CREATE INDEX IF NOT EXISTS idx_logs_feedId ON refresh_logs(feedId)
        """)

        try db?.execute("""
            CREATE TABLE IF NOT EXISTS app_meta (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        """)

        try db?.execute("""
            CREATE TABLE IF NOT EXISTS saved_sentences (
                id TEXT PRIMARY KEY,
                sentence TEXT NOT NULL,
                translation TEXT,
                notes TEXT,
                articleId TEXT,
                articleTitle TEXT,
                paragraphIndex INTEGER DEFAULT 0,
                charOffset INTEGER DEFAULT 0,
                source TEXT,
                categoryIds TEXT,
                createdAt REAL NOT NULL
            )
        """)

        try db?.execute("""
            CREATE INDEX IF NOT EXISTS idx_sentences_articleId ON saved_sentences(articleId)
        """)

        try db?.execute("""
            CREATE INDEX IF NOT EXISTS idx_sentences_createdAt ON saved_sentences(createdAt)
        """)
    }

    func ensureVocabularyCategoryIdsColumn() {
        try? db?.execute("ALTER TABLE vocabulary ADD COLUMN categoryIds TEXT")
    }

    func sanitizeLiteralNilValues() {
        let cleanupStatements = [
            "UPDATE feeds SET description = NULL WHERE description = 'nil'",
            "UPDATE feeds SET notes = NULL WHERE notes = 'nil'",
            "UPDATE feeds SET imageUrl = NULL WHERE imageUrl = 'nil'",
            "UPDATE feeds SET etag = NULL WHERE etag = 'nil'",
            "UPDATE feeds SET lastModified = NULL WHERE lastModified = 'nil'"
        ]

        for statement in cleanupStatements {
            try? db?.execute(statement)
        }
    }

    func uniqueCategoryIds(from categoryIds: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return categoryIds.filter { seen.insert($0).inserted }
    }

    // MARK: - UserDefaults Migration

    private func migrateFromUserDefaults() throws {
        let defaults = UserDefaults.standard
        let versionRow = try db?.query("SELECT value FROM app_meta WHERE key = 'data_version'")
        let version = versionRow?.first?["value"] as? String

        guard version == nil else { return }

        print("📦 Migrating data from UserDefaults to SQLite...")

        // Migrate feeds
        if let data = defaults.data(forKey: "linguadigest_feeds"),
           let feeds = try? JSONDecoder().decode([Feed].self, from: data) {
            for feed in feeds {
                try insertFeed(feed)
            }
            print("  ✅ Migrated \(feeds.count) feeds")
        }

        // Migrate articles (main + favorites)
        var allArticles: [Article] = []
        if let data = defaults.data(forKey: "linguadigest_articles"),
           let articles = try? JSONDecoder().decode([Article].self, from: data) {
            allArticles.append(contentsOf: articles)
        }
        if let data = defaults.data(forKey: "linguadigest_favorite_articles"),
           let favorites = try? JSONDecoder().decode([Article].self, from: data) {
            for fav in favorites {
                if !allArticles.contains(where: { $0.id == fav.id }) {
                    var restored = fav
                    restored.isFavorite = true
                    allArticles.insert(restored, at: 0)
                }
            }
        }
        for article in allArticles {
            try insertArticle(article)
        }
        print("  ✅ Migrated \(allArticles.count) articles")

        // Migrate vocabulary
        if let data = defaults.data(forKey: "linguadigest_vocabulary"),
           let vocab = try? JSONDecoder().decode([Vocabulary].self, from: data) {
            for v in vocab {
                try insertVocabulary(v)
            }
            print("  ✅ Migrated \(vocab.count) vocabulary items")
        }

        // Migrate categories
        if let data = defaults.data(forKey: "linguadigest_categories"),
           let cats = try? JSONDecoder().decode([VocabularyCategory].self, from: data) {
            for cat in cats {
                try insertCategory(cat)
            }
            print("  ✅ Migrated \(cats.count) categories")
        }

        // Migrate refresh logs
        if let data = defaults.data(forKey: "linguadigest_refresh_logs"),
           let logs = try? JSONDecoder().decode([RefreshLogEntry].self, from: data) {
            for log in logs {
                try insertRefreshLog(log)
            }
            print("  ✅ Migrated \(logs.count) refresh logs")
        }

        try db?.execute("INSERT OR REPLACE INTO app_meta (key, value) VALUES ('data_version', '1')")
        print("✅ Migration complete")
    }

    // MARK: - Category Initialization

    private func initializeCategories() {
        let stored = fetchAllCategories()
        if stored.isEmpty {
            for cat in VocabularyCategory.defaultCategories {
                try? insertCategory(cat)
            }
        }
    }

    // MARK: - Row Mapper Helpers

    func optionalString(_ value: Any?) -> String? {
        guard let string = value as? String, string != "nil", !string.isEmpty else { return nil }
        return string
    }
}
