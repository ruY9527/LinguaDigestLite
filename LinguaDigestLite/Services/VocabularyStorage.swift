import Foundation

/// Vocabulary CRUD 操作扩展
extension DatabaseManager {

    func insertVocabulary(_ vocab: Vocabulary) throws {
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

    func notifyVocabularyDidChange() {
        NotificationCenter.default.post(name: .vocabularyDidChange, object: nil)
    }
}
