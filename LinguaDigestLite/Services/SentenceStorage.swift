import Foundation

/// SavedSentence CRUD 操作扩展
extension DatabaseManager {

    func insertSentence(_ sentence: SavedSentence) throws {
        let categoryIdsJSON: String?
        if let data = try? JSONEncoder().encode(sentence.categoryIds.map(\.uuidString)) {
            categoryIdsJSON = String(data: data, encoding: .utf8)
        } else {
            categoryIdsJSON = nil
        }

        try db?.execute("""
            INSERT OR REPLACE INTO saved_sentences
            (id, sentence, translation, notes, articleId, articleTitle,
             paragraphIndex, charOffset, source, categoryIds, createdAt)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, params: [
            sentence.id.uuidString, sentence.sentence,
            sentence.translation as Any, sentence.notes as Any,
            sentence.articleId?.uuidString as Any, sentence.articleTitle as Any,
            sentence.paragraphIndex, sentence.charOffset,
            sentence.source as Any, categoryIdsJSON as Any,
            sentence.createdAt.timeIntervalSince1970
        ])
    }

    func fetchAllSentences() -> [SavedSentence] {
        guard let rows = try? db?.query("SELECT * FROM saved_sentences ORDER BY createdAt DESC") else { return [] }
        return rows.compactMap(sentenceFromRow)
    }

    func fetchSentences(for categoryId: UUID?) -> [SavedSentence] {
        let all = fetchAllSentences()
        guard let categoryId else { return all }
        return all.filter { $0.belongs(to: categoryId) }
    }

    func fetchSentences(forArticleId articleId: UUID) -> [SavedSentence] {
        guard let rows = try? db?.query(
            "SELECT * FROM saved_sentences WHERE articleId = ? ORDER BY charOffset ASC",
            params: [articleId.uuidString]
        ) else { return [] }
        return rows.compactMap(sentenceFromRow)
    }

    func addSentence(_ sentence: SavedSentence) -> SavedSentence {
        try? insertSentence(sentence)
        notifySentenceDidChange()
        return sentence
    }

    func updateSentence(_ sentence: SavedSentence) {
        try? insertSentence(sentence)
        notifySentenceDidChange()
    }

    func deleteSentence(_ sentence: SavedSentence) {
        try? db?.execute("DELETE FROM saved_sentences WHERE id = ?", params: [sentence.id.uuidString])
        notifySentenceDidChange()
    }

    func sentenceCount(for categoryId: UUID? = nil) -> Int {
        if categoryId == nil {
            let rows = try? db?.query("SELECT COUNT(*) as cnt FROM saved_sentences")
            return Int(rows?.first?["cnt"] as? Int64 ?? 0)
        }
        return fetchAllSentences().filter { $0.belongs(to: categoryId!) }.count
    }

    private func sentenceFromRow(_ row: [String: Any]) -> SavedSentence? {
        guard let idStr = row["id"] as? String, let id = UUID(uuidString: idStr),
              let sentence = row["sentence"] as? String else { return nil }

        let decodedCategoryIds: [UUID]
        if let jsonStr = row["categoryIds"] as? String,
           let data = jsonStr.data(using: .utf8),
           let rawIds = try? JSONDecoder().decode([String].self, from: data) {
            decodedCategoryIds = rawIds.compactMap(UUID.init)
        } else {
            decodedCategoryIds = []
        }

        return SavedSentence(
            id: id,
            sentence: sentence,
            translation: row["translation"] as? String,
            notes: row["notes"] as? String,
            articleId: (row["articleId"] as? String).flatMap(UUID.init),
            articleTitle: row["articleTitle"] as? String,
            paragraphIndex: Int(row["paragraphIndex"] as? Int64 ?? 0),
            charOffset: Int(row["charOffset"] as? Int64 ?? 0),
            source: row["source"] as? String,
            categoryIds: decodedCategoryIds,
            createdAt: (row["createdAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
        )
    }

    func notifySentenceDidChange() {
        NotificationCenter.default.post(name: .sentenceDidChange, object: nil)
    }
}
