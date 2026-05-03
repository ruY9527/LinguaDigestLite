import Foundation

/// RefreshLog CRUD 操作扩展
extension DatabaseManager {

    func insertRefreshLog(_ log: RefreshLogEntry) throws {
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
}
