import Foundation

/// Feed CRUD 操作扩展
extension DatabaseManager {

    func insertFeed(_ feed: Feed) throws {
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
}
