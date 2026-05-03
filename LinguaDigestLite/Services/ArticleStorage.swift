import Foundation

/// Article CRUD 操作扩展
extension DatabaseManager {

    func insertArticle(_ article: Article) throws {
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
                let existing = try? db?.query(
                    "SELECT id, content, imageUrl FROM articles WHERE link = ? AND feedId = ?",
                    params: [article.link, article.feedId?.uuidString as Any]
                )

                if let existingRow = existing?.first {
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
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 3600).timeIntervalSince1970
        try? db?.execute("""
            DELETE FROM articles WHERE isFavorite = 0 AND isRead = 1
            AND publishedAt IS NOT NULL AND publishedAt < ?
        """, params: [thirtyDaysAgo])

        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600).timeIntervalSince1970
        try? db?.execute("""
            DELETE FROM articles WHERE isFavorite = 0 AND isRead = 0
            AND publishedAt IS NOT NULL AND publishedAt < ?
        """, params: [sevenDaysAgo])
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
