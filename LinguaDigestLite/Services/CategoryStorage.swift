import Foundation

/// Category CRUD 操作扩展
extension DatabaseManager {

    func insertCategory(_ cat: VocabularyCategory) throws {
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
        for var sentence in fetchAllSentences() where sentence.belongs(to: category.id) {
            sentence.categoryIds.removeAll { $0 == category.id }
            updateSentence(sentence)
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
}
