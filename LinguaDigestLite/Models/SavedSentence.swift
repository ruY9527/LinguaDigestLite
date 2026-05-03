//
//  SavedSentence.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation

/// 收藏句子模型
struct SavedSentence: Identifiable, Codable {
    var id: UUID
    var sentence: String
    var translation: String?
    var notes: String?
    var articleId: UUID?
    var articleTitle: String?
    var paragraphIndex: Int
    var charOffset: Int
    var source: String?
    var categoryIds: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        sentence: String,
        translation: String? = nil,
        notes: String? = nil,
        articleId: UUID? = nil,
        articleTitle: String? = nil,
        paragraphIndex: Int = 0,
        charOffset: Int = 0,
        source: String? = nil,
        categoryIds: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sentence = sentence
        self.translation = translation
        self.notes = notes
        self.articleId = articleId
        self.articleTitle = articleTitle
        self.paragraphIndex = paragraphIndex
        self.charOffset = charOffset
        self.source = source
        self.categoryIds = categoryIds
        self.createdAt = createdAt
    }
}

extension SavedSentence {
    func belongs(to categoryId: UUID) -> Bool {
        categoryIds.contains(categoryId)
    }
}
