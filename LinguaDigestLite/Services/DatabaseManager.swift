import Foundation

/// 数据库管理器 - 使用SQLite本地存储
class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: SQLiteHelper?
    private let dbPath: String
    private let articleQueue = DispatchQueue(label: "com.linguadigest.articleQueue")

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
    }

    private func ensureVocabularyCategoryIdsColumn() {
        try? db?.execute("ALTER TABLE vocabulary ADD COLUMN categoryIds TEXT")
    }

    private func sanitizeLiteralNilValues() {
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

    private func uniqueCategoryIds(from categoryIds: [UUID]) -> [UUID] {
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

    // MARK: - Feed Operations

    private func insertFeed(_ feed: Feed) throws {
        try db?.execute("""
            INSERT OR REPLACE INTO feeds
            (id, title, link, feedUrl, description, notes, imageUrl, lastUpdated,
             isActive, isBuiltIn, createdAt, updateInterval, etag, lastModified, lastRefreshTime, consecutiveErrors)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            feed.id.uuidString, feed.title, feed.link, feed.feedUrl,
            feed.description as Any, feed.notes as Any, feed.imageUrl as Any,
            feed.lastUpdated?.timeIntervalSince1970 as Any,
            feed.isActive ? 1 : 0, feed.isBuiltIn ? 1 : 0,
            feed.createdAt.timeIntervalSince1970, feed.updateInterval,
            feed.etag as Any, feed.lastModified as Any,
            feed.lastRefreshTime?.timeIntervalSince1970 as Any,
            feed.consecutiveErrors
        ])
    }

    func fetchAllFeeds() -> [Feed] {
        guard let rows = try? db?.query("SELECT * FROM feeds ORDER BY isBuiltIn DESC, createdAt ASC") else { return [] }
        return rows.compactMap(feedFromRow)
    }

    func fetchActiveFeeds() -> [Feed] {
        guard let rows = try? db?.query("SELECT * FROM feeds WHERE isActive = 1 ORDER BY isBuiltIn DESC, createdAt ASC") else { return [] }
        return rows.compactMap(feedFromRow)
    }

    func addFeed(_ feed: Feed) -> Feed {
        try? insertFeed(feed)
        return feed
    }

    func updateFeed(_ feed: Feed) {
        try? insertFeed(feed) // INSERT OR REPLACE
    }

    func deleteFeed(_ feed: Feed) {
        try? db?.execute("DELETE FROM feeds WHERE id = ?", params: [feed.id.uuidString])
        // Delete non-favorite articles for this feed
        try? db?.execute("DELETE FROM articles WHERE feedId = ? AND isFavorite = 0", params: [feed.id.uuidString])
    }

    func syncBuiltInFeeds() {
        let catalog = Feed.builtInFeeds
        let catalogByURL = Dictionary(uniqueKeysWithValues: catalog.map { ($0.feedUrl, $0) })

        // Update existing built-in feeds
        let existing = fetchAllFeeds().filter { $0.isBuiltIn }
        for feed in existing {
            if let catalogFeed = catalogByURL[feed.feedUrl] {
                var updated = feed
                updated.title = catalogFeed.title
                updated.link = catalogFeed.link
                updated.description = catalogFeed.description
                updated.isBuiltIn = true
                try? insertFeed(updated)
            }
        }

        // Add missing built-in feeds
        let existingURLs = Set(existing.map(\.feedUrl))
        for catalogFeed in catalog where !existingURLs.contains(catalogFeed.feedUrl) {
            try? insertFeed(catalogFeed)
        }

        // Remove built-in feeds no longer in catalog
        let catalogURLs = Set(catalog.map(\.feedUrl))
        for feed in existing where !catalogURLs.contains(feed.feedUrl) {
            try? db?.execute("DELETE FROM feeds WHERE id = ?", params: [feed.id.uuidString])
        }
    }

    func resetBuiltInFeeds() {
        syncBuiltInFeeds()
        try? db?.execute("""
            DELETE FROM articles WHERE isFavorite = 0
            AND feedId IN (SELECT id FROM feeds WHERE isBuiltIn = 1)
        """)
    }

    private func feedFromRow(_ row: [String: Any]) -> Feed? {
        guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
              let title = row["title"] as? String,
              let feedUrl = row["feedUrl"] as? String else { return nil }

        var feed = Feed(
            id: id,
            title: title,
            link: (row["link"] as? String) ?? "",
            feedUrl: feedUrl,
            description: optionalString(row["description"]),
            notes: optionalString(row["notes"]),
            imageUrl: optionalString(row["imageUrl"]),
            isBuiltIn: (row["isBuiltIn"] as? Int64) == 1,
            updateInterval: Int(row["updateInterval"] as? Int64 ?? 60),
            etag: optionalString(row["etag"]),
            lastModified: optionalString(row["lastModified"]),
            lastRefreshTime: (row["lastRefreshTime"] as? Double).map { Date(timeIntervalSince1970: $0) },
            consecutiveErrors: Int(row["consecutiveErrors"] as? Int64 ?? 0)
        )
        feed.isActive = (row["isActive"] as? Int64) == 1
        feed.lastUpdated = (row["lastUpdated"] as? Double).map { Date(timeIntervalSince1970: $0) }
        if let createdAtTs = row["createdAt"] as? Double {
            feed.createdAt = Date(timeIntervalSince1970: createdAtTs)
        }
        return feed
    }

    private func optionalString(_ value: Any?) -> String? {
        guard let string = value as? String, string != "nil", !string.isEmpty else { return nil }
        return string
    }

    // MARK: - Article Operations

    private func insertArticle(_ article: Article) throws {
        try db?.execute("""
            INSERT OR REPLACE INTO articles
            (id, feedId, title, link, author, summary, content, htmlContent,
             imageUrl, publishedAt, fetchedAt, isRead, isFavorite, readingProgress)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            article.id.uuidString, article.feedId?.uuidString as Any,
            article.title, article.link,
            article.author as Any, article.summary as Any,
            article.content as Any, article.htmlContent as Any,
            article.imageUrl as Any,
            article.publishedAt?.timeIntervalSince1970 as Any,
            article.fetchedAt.timeIntervalSince1970,
            article.isRead ? 1 : 0, article.isFavorite ? 1 : 0,
            article.readingProgress
        ])
    }

    func fetchAllArticles() -> [Article] {
        guard let rows = try? db?.query("SELECT * FROM articles ORDER BY publishedAt DESC, fetchedAt DESC") else { return [] }
        return rows.compactMap(articleFromRow)
    }

    func fetchArticles(for feedId: UUID) -> [Article] {
        guard let rows = try? db?.query(
            "SELECT * FROM articles WHERE feedId = ? ORDER BY publishedAt DESC",
            params: [feedId.uuidString]
        ) else { return [] }
        return rows.compactMap(articleFromRow)
    }

    func fetchFavoriteArticles() -> [Article] {
        guard let rows = try? db?.query("SELECT * FROM articles WHERE isFavorite = 1 ORDER BY fetchedAt DESC") else { return [] }
        return rows.compactMap(articleFromRow)
    }

    func fetchUnreadArticles() -> [Article] {
        guard let rows = try? db?.query("SELECT * FROM articles WHERE isRead = 0 ORDER BY publishedAt DESC") else { return [] }
        return rows.compactMap(articleFromRow)
    }

    func addArticle(_ article: Article) -> Article {
        try? insertArticle(article)
        return article
    }

    func updateArticle(_ article: Article) {
        try? db?.execute("""
            UPDATE articles SET title = ?, author = ?, summary = ?, content = ?,
            htmlContent = ?, imageUrl = ?, isRead = ?, isFavorite = ?, readingProgress = ?
            WHERE id = ?
        """, params: [
            article.title, article.author as Any, article.summary as Any,
            article.content as Any, article.htmlContent as Any, article.imageUrl as Any,
            article.isRead ? 1 : 0, article.isFavorite ? 1 : 0, article.readingProgress,
            article.id.uuidString
        ])
    }

    func articleExists(link: String, feedId: UUID?) -> Bool {
        let rows = try? db?.query(
            "SELECT COUNT(*) as cnt FROM articles WHERE link = ? AND feedId = ?",
            params: [link, feedId?.uuidString as Any]
        )
        return (rows?.first?["cnt"] as? Int64 ?? 0) > 0
    }

    /// Batch add articles with dedup by (link, feedId). Updates existing articles' content if richer.
    func addArticles(_ articles: [Article]) -> Int {
        return articleQueue.sync {
            var addedCount = 0
            for article in articles {
                // Check if article exists with same link + feedId
                let existing = try? db?.query(
                    "SELECT id, content, imageUrl FROM articles WHERE link = ? AND feedId = ?",
                    params: [article.link, article.feedId?.uuidString as Any]
                )

                if let existingRow = existing?.first {
                    // Article exists - update content if richer
                    let existingContentLen = (existingRow["content"] as? String)?.count ?? 0
                    let existingImageUrl = existingRow["imageUrl"] as? String

                    var shouldUpdateContent = false
                    var newContent: String? = nil
                    if let nc = article.content, !nc.isEmpty, nc.count > existingContentLen {
                        newContent = nc
                        shouldUpdateContent = true
                    }

                    var shouldUpdateImage = false
                    var newImageUrl: String? = nil
                    if let ni = article.imageUrl, !ni.isEmpty,
                       existingImageUrl == nil || existingImageUrl?.isEmpty == true {
                        newImageUrl = ni
                        shouldUpdateImage = true
                    }

                    // Always update title, summary, author
                    try? db?.execute("""
                        UPDATE articles SET title = ?, summary = ?, author = ?,
                        content = CASE WHEN ? THEN ? ELSE content END,
                        imageUrl = CASE WHEN ? THEN ? ELSE imageUrl END
                        WHERE id = ?
                    """, params: [
                        article.title, article.summary as Any, article.author as Any,
                        shouldUpdateContent ? 1 : 0, newContent as Any,
                        shouldUpdateImage ? 1 : 0, newImageUrl as Any,
                        (existingRow["id"] as? String) ?? ""
                    ])
                } else {
                    // New article
                    try? insertArticle(article)
                    addedCount += 1
                }
            }
            return addedCount
        }
    }

    func markArticleAsRead(_ article: Article) {
        try? db?.execute("UPDATE articles SET isRead = 1 WHERE id = ?", params: [article.id.uuidString])
    }

    func toggleArticleFavorite(_ article: Article) -> Bool {
        let rows = try? db?.query("SELECT isFavorite FROM articles WHERE id = ?", params: [article.id.uuidString])
        guard let row = rows?.first else { return false }
        let current = (row["isFavorite"] as? Int64) == 1
        let newStatus = !current
        try? db?.execute("UPDATE articles SET isFavorite = ? WHERE id = ?", params: [newStatus ? 1 : 0, article.id.uuidString])
        return newStatus
    }

    func updateReadingProgress(_ article: Article, progress: Double) {
        try? db?.execute("UPDATE articles SET readingProgress = ? WHERE id = ?", params: [progress, article.id.uuidString])
    }

    func deleteArticle(_ article: Article) {
        try? db?.execute("DELETE FROM articles WHERE id = ? AND isFavorite = 0", params: [article.id.uuidString])
    }

    func deleteFavoriteArticle(_ article: Article) {
        try? db?.execute("DELETE FROM articles WHERE id = ?", params: [article.id.uuidString])
    }

    // MARK: - Article Cleanup

    func cleanupOldArticles() {
        // Read articles older than 30 days (except favorites)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600).timeIntervalSince1970
        try? db?.execute("""
            DELETE FROM articles WHERE isFavorite = 0 AND isRead = 1
            AND publishedAt IS NOT NULL AND publishedAt < ?
        """, params: [thirtyDaysAgo])

        // Unread articles older than 7 days (except favorites)
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600).timeIntervalSince1970
        try? db?.execute("""
            DELETE FROM articles WHERE isFavorite = 0 AND isRead = 0
            AND publishedAt IS NOT NULL AND publishedAt < ?
        """, params: [sevenDaysAgo])
    }

    // MARK: - Category Operations

    private func insertCategory(_ cat: VocabularyCategory) throws {
        try db?.execute("""
            INSERT OR REPLACE INTO categories
            (id, name, description, color, icon, createdAt, isDefault, "order")
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            cat.id.uuidString, cat.name, cat.description as Any,
            cat.color, cat.icon,
            cat.createdAt.timeIntervalSince1970,
            cat.isDefault ? 1 : 0, cat.order
        ])
    }

    func fetchAllCategories() -> [VocabularyCategory] {
        guard let rows = try? db?.query("SELECT * FROM categories ORDER BY \"order\" ASC") else { return [] }
        return rows.compactMap(categoryFromRow)
    }

    func addCategory(_ category: VocabularyCategory) -> VocabularyCategory {
        var cat = category
        let count = fetchAllCategories().count
        cat.order = count
        try? insertCategory(cat)
        return cat
    }

    func updateCategory(_ category: VocabularyCategory) {
        try? insertCategory(category)
    }

    func deleteCategory(_ category: VocabularyCategory) {
        if category.isDefault { return }
        try? db?.execute("DELETE FROM categories WHERE id = ?", params: [category.id.uuidString])
        for var vocabulary in fetchAllVocabulary() where vocabulary.belongs(to: category.id) {
            vocabulary.categoryIds.removeAll { $0 == category.id }
            vocabulary.categoryId = vocabulary.categoryIds.first
            updateVocabulary(vocabulary)
        }
    }

    func fetchCategory(by id: UUID) -> VocabularyCategory? {
        guard let rows = try? db?.query("SELECT * FROM categories WHERE id = ?", params: [id.uuidString]) else { return nil }
        return rows.compactMap(categoryFromRow).first
    }

    private func categoryFromRow(_ row: [String: Any]) -> VocabularyCategory? {
        guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
              let name = row["name"] as? String else { return nil }

        return VocabularyCategory(
            id: id,
            name: name,
            description: row["description"] as? String,
            color: (row["color"] as? String) ?? "#007AFF",
            icon: (row["icon"] as? String) ?? "folder",
            isDefault: (row["isDefault"] as? Int64) == 1,
            order: Int(row["order"] as? Int64 ?? 0)
        )
    }

    // MARK: - Vocabulary Operations

    private func insertVocabulary(_ vocab: Vocabulary) throws {
        let groupedJSON: String?
        if let grouped = vocab.groupedDefinitions, let data = try? JSONEncoder().encode(grouped) {
            groupedJSON = String(data: data, encoding: .utf8)
        } else {
            groupedJSON = nil
        }

        let normalizedCategoryIds = uniqueCategoryIds(from: vocab.categoryIds + (vocab.categoryId.map { [$0] } ?? []))
        let categoryIdsJSON: String?
        if let data = try? JSONEncoder().encode(normalizedCategoryIds.map(\.uuidString)) {
            categoryIdsJSON = String(data: data, encoding: .utf8)
        } else {
            categoryIdsJSON = nil
        }

        try db?.execute("""
            INSERT OR REPLACE INTO vocabulary
            (id, word, definition, phonetic, partOfSpeech, contextSnippet, exampleSentence,
             articleId, categoryId, categoryIds, englishDefinition, groupedDefinitions, masteredLevel,
             nextReviewDate, addedAt, lastReviewedAt, reviewCount, easeFactor, interval)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            vocab.id.uuidString, vocab.word, vocab.definition as Any,
            vocab.phonetic as Any, vocab.partOfSpeech as Any,
            vocab.contextSnippet as Any, vocab.exampleSentence as Any,
            vocab.articleId?.uuidString as Any, normalizedCategoryIds.first?.uuidString as Any, categoryIdsJSON as Any,
            vocab.englishDefinition as Any, groupedJSON as Any,
            vocab.masteredLevel,
            vocab.nextReviewDate?.timeIntervalSince1970 as Any,
            vocab.addedAt.timeIntervalSince1970,
            vocab.lastReviewedAt?.timeIntervalSince1970 as Any,
            vocab.reviewCount, vocab.easeFactor, vocab.interval
        ])
    }

    func fetchAllVocabulary() -> [Vocabulary] {
        guard let rows = try? db?.query("SELECT * FROM vocabulary ORDER BY addedAt DESC") else { return [] }
        return rows.compactMap(vocabularyFromRow)
    }

    func fetchVocabulary(for categoryId: UUID?) -> [Vocabulary] {
        let allVocabulary = fetchAllVocabulary()
        guard let categoryId else { return allVocabulary }
        return allVocabulary.filter { $0.belongs(to: categoryId) }
    }

    func fetchTodayReviewVocabulary(for categoryId: UUID? = nil) -> [Vocabulary] {
        let now = Date().timeIntervalSince1970
        let sql = "SELECT * FROM vocabulary WHERE nextReviewDate IS NULL OR nextReviewDate <= ? ORDER BY addedAt DESC"
        let params: [Any] = [now]
        guard let rows = try? db?.query(sql, params: params) else { return [] }
        let dueVocabulary = rows.compactMap(vocabularyFromRow)
        guard let categoryId else { return dueVocabulary }
        return dueVocabulary.filter { $0.belongs(to: categoryId) }
    }

    func searchVocabulary(_ word: String) -> Vocabulary? {
        guard let rows = try? db?.query(
            "SELECT * FROM vocabulary WHERE LOWER(word) = ? LIMIT 1",
            params: [word.lowercased()]
        ) else { return nil }
        return rows.compactMap(vocabularyFromRow).first
    }

    func addVocabulary(_ vocabulary: Vocabulary) -> Vocabulary {
        // Check if word already exists
        if let existing = searchVocabulary(vocabulary.word) {
            var updated = existing
            if let def = vocabulary.definition, !def.isEmpty { updated.definition = def }
            if updated.partOfSpeech == nil || updated.partOfSpeech?.isEmpty == true,
               let pos = vocabulary.partOfSpeech, !pos.isEmpty { updated.partOfSpeech = pos }
            if updated.phonetic == nil || updated.phonetic?.isEmpty == true,
               let ph = vocabulary.phonetic, !ph.isEmpty { updated.phonetic = ph }
            if updated.contextSnippet == nil || updated.contextSnippet?.isEmpty == true,
               let ctx = vocabulary.contextSnippet, !ctx.isEmpty { updated.contextSnippet = ctx }
            if updated.exampleSentence == nil,
               let ex = vocabulary.exampleSentence, !ex.isEmpty { updated.exampleSentence = ex }
            updated.categoryIds = uniqueCategoryIds(from: updated.categoryIds + vocabulary.categoryIds + (vocabulary.categoryId.map { [$0] } ?? []))
            updated.categoryId = updated.categoryIds.first
            if let grouped = vocabulary.groupedDefinitions, !grouped.isEmpty { updated.groupedDefinitions = grouped }
            if let engDef = vocabulary.englishDefinition, !engDef.isEmpty { updated.englishDefinition = engDef }
            try? insertVocabulary(updated)
            notifyVocabularyDidChange()
            return updated
        }

        var vocab = vocabulary
        vocab.word = vocabulary.word.lowercased()
        try? insertVocabulary(vocab)
        notifyVocabularyDidChange()
        return vocab
    }

    func updateVocabulary(_ vocabulary: Vocabulary) {
        try? insertVocabulary(vocabulary)
        notifyVocabularyDidChange()
    }

    func updateVocabularyCategory(_ vocabulary: Vocabulary, categoryId: UUID?) {
        var updatedVocabulary = vocabulary
        updatedVocabulary.categoryIds = categoryId.map { [$0] } ?? []
        updatedVocabulary.categoryId = categoryId
        updateVocabulary(updatedVocabulary)
    }

    func deleteVocabulary(_ vocabulary: Vocabulary) {
        try? db?.execute("DELETE FROM vocabulary WHERE id = ?", params: [vocabulary.id.uuidString])
        notifyVocabularyDidChange()
    }

    func vocabularyCount(for categoryId: UUID? = nil) -> Int {
        if categoryId == nil {
            let rows = try? db?.query("SELECT COUNT(*) as cnt FROM vocabulary")
            return Int(rows?.first?["cnt"] as? Int64 ?? 0)
        }
        return fetchAllVocabulary().filter { $0.belongs(to: categoryId!) }.count
    }

    func masteredVocabularyCount(for categoryId: UUID? = nil) -> Int {
        if categoryId == nil {
            let rows = try? db?.query("SELECT COUNT(*) as cnt FROM vocabulary WHERE masteredLevel >= 4")
            return Int(rows?.first?["cnt"] as? Int64 ?? 0)
        }
        return fetchAllVocabulary().filter { $0.masteredLevel >= 4 && $0.belongs(to: categoryId!) }.count
    }

    private func vocabularyFromRow(_ row: [String: Any]) -> Vocabulary? {
        guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
              let word = row["word"] as? String else { return nil }

        let groupedDefs: [PosDefinitions]?
        if let jsonStr = row["groupedDefinitions"] as? String,
           let data = jsonStr.data(using: .utf8) {
            groupedDefs = try? JSONDecoder().decode([PosDefinitions].self, from: data)
        } else {
            groupedDefs = nil
        }

        let legacyCategoryId = (row["categoryId"] as? String).flatMap(UUID.init)
        let decodedCategoryIds: [UUID]
        if let jsonStr = row["categoryIds"] as? String,
           let data = jsonStr.data(using: .utf8),
           let rawIds = try? JSONDecoder().decode([String].self, from: data) {
            decodedCategoryIds = rawIds.compactMap(UUID.init)
        } else if let legacyCategoryId {
            decodedCategoryIds = [legacyCategoryId]
        } else {
            decodedCategoryIds = []
        }

        return Vocabulary(
            id: id,
            word: word,
            definition: row["definition"] as? String,
            phonetic: row["phonetic"] as? String,
            partOfSpeech: row["partOfSpeech"] as? String,
            exampleSentence: row["exampleSentence"] as? String,
            articleId: (row["articleId"] as? String).flatMap(UUID.init),
            categoryId: decodedCategoryIds.first ?? legacyCategoryId,
            categoryIds: decodedCategoryIds,
            contextSnippet: row["contextSnippet"] as? String,
            nextReviewDate: (row["nextReviewDate"] as? Double).map(Date.init(timeIntervalSince1970:)),
            reviewCount: Int(row["reviewCount"] as? Int64 ?? 0),
            easeFactor: row["easeFactor"] as? Double ?? 2.5,
            interval: Int(row["interval"] as? Int64 ?? 0),
            addedAt: (row["addedAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date(),
            lastReviewedAt: (row["lastReviewedAt"] as? Double).map(Date.init(timeIntervalSince1970:)),
            masteredLevel: Int(row["masteredLevel"] as? Int64 ?? 0),
            groupedDefinitions: groupedDefs,
            englishDefinition: row["englishDefinition"] as? String
        )
    }

    private func notifyVocabularyDidChange() {
        NotificationCenter.default.post(name: .vocabularyDidChange, object: nil)
    }

    // MARK: - Refresh Log Operations

    private func insertRefreshLog(_ log: RefreshLogEntry) throws {
        try db?.execute("""
            INSERT INTO refresh_logs (id, feedId, feedTitle, isSuccess, errorMessage, statusCode, addedCount, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            log.id.uuidString, log.feedId.uuidString, log.feedTitle,
            log.isSuccess ? 1 : 0, log.errorMessage as Any,
            log.statusCode as Any, log.addedCount,
            log.timestamp.timeIntervalSince1970
        ])
    }

    func addRefreshLog(_ log: RefreshLogEntry) {
        try? insertRefreshLog(log)
        // Trim old logs (keep last 300)
        try? db?.execute("""
            DELETE FROM refresh_logs WHERE id NOT IN (
                SELECT id FROM refresh_logs ORDER BY timestamp DESC LIMIT 300
            )
        """)
    }

    func fetchAllRefreshLogs() -> [RefreshLogEntry] {
        guard let rows = try? db?.query("SELECT * FROM refresh_logs ORDER BY timestamp DESC") else { return [] }
        return rows.compactMap(refreshLogFromRow)
    }

    func fetchRefreshLogs(for feedId: UUID) -> [RefreshLogEntry] {
        guard let rows = try? db?.query(
            "SELECT * FROM refresh_logs WHERE feedId = ? ORDER BY timestamp DESC",
            params: [feedId.uuidString]
        ) else { return [] }
        return rows.compactMap(refreshLogFromRow)
    }

    func latestRefreshLog(for feedId: UUID) -> RefreshLogEntry? {
        guard let rows = try? db?.query(
            "SELECT * FROM refresh_logs WHERE feedId = ? ORDER BY timestamp DESC LIMIT 1",
            params: [feedId.uuidString]
        ) else { return nil }
        return rows.compactMap(refreshLogFromRow).first
    }

    func clearAllRefreshLogs() {
        try? db?.execute("DELETE FROM refresh_logs")
    }

    func clearRefreshLogs(for feedId: UUID) {
        try? db?.execute("DELETE FROM refresh_logs WHERE feedId = ?", params: [feedId.uuidString])
    }

    private func refreshLogFromRow(_ row: [String: Any]) -> RefreshLogEntry? {
        guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
              let feedIdStr = row["feedId"] as? String, let feedId = UUID(uuidString: feedIdStr),
              let feedTitle = row["feedTitle"] as? String else { return nil }

        return RefreshLogEntry(
            id: id,
            feedId: feedId,
            feedTitle: feedTitle,
            isSuccess: (row["isSuccess"] as? Int64) == 1,
            errorMessage: row["errorMessage"] as? String,
            statusCode: (row["statusCode"] as? Int64).map(Int.init),
            addedCount: Int(row["addedCount"] as? Int64 ?? 0),
            timestamp: Date(timeIntervalSince1970: row["timestamp"] as? Double ?? 0)
        )
    }

    // MARK: - Article Row Mapper

    private func articleFromRow(_ row: [String: Any]) -> Article? {
        guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
              let title = row["title"] as? String,
              let link = row["link"] as? String else { return nil }

        var article = Article(
            id: id,
            feedId: (row["feedId"] as? String).flatMap(UUID.init),
            title: title,
            link: link,
            author: row["author"] as? String,
            summary: row["summary"] as? String,
            content: row["content"] as? String,
            htmlContent: row["htmlContent"] as? String,
            imageUrl: row["imageUrl"] as? String,
            publishedAt: (row["publishedAt"] as? Double).map { Date(timeIntervalSince1970: $0) }
        )
        article.fetchedAt = Date(timeIntervalSince1970: row["fetchedAt"] as? Double ?? 0)
        article.isRead = (row["isRead"] as? Int64) == 1
        article.isFavorite = (row["isFavorite"] as? Int64) == 1
        article.readingProgress = row["readingProgress"] as? Double ?? 0.0
        return article
    }
}
