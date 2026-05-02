//
//  Vocabulary.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation

/// 按词性分组的释义
struct PosDefinitions: Codable, Equatable {
    let pos: String
    let definitions: [String]
}

/// 生词模型（简化版，不依赖GRDB）
struct Vocabulary: Identifiable, Codable {
    var id: UUID
    var word: String
    var definition: String?
    var phonetic: String?
    var partOfSpeech: String?
    var exampleSentence: String?
    var articleId: UUID?
    var categoryId: UUID? // 分类ID
    var contextSnippet: String? // 原文上下文片段
    var nextReviewDate: Date?
    var reviewCount: Int
    var easeFactor: Double // SM-2算法的难度因子
    var interval: Int // 复习间隔（天）
    var addedAt: Date
    var lastReviewedAt: Date?
    var masteredLevel: Int // 0-5 掌握程度
    var groupedDefinitions: [PosDefinitions]? // 按词性分组的多个释义
    var englishDefinition: String? // 英文释义

    init(
        id: UUID = UUID(),
        word: String,
        definition: String? = nil,
        phonetic: String? = nil,
        partOfSpeech: String? = nil,
        exampleSentence: String? = nil,
        articleId: UUID? = nil,
        categoryId: UUID? = nil,
        contextSnippet: String? = nil,
        groupedDefinitions: [PosDefinitions]? = nil,
        englishDefinition: String? = nil
    ) {
        self.id = id
        self.word = word.lowercased()
        self.definition = definition
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.exampleSentence = exampleSentence
        self.articleId = articleId
        self.categoryId = categoryId
        self.contextSnippet = contextSnippet
        self.reviewCount = 0
        self.easeFactor = 2.5 // SM-2默认值
        self.interval = 0
        self.addedAt = Date()
        self.masteredLevel = 0
        self.groupedDefinitions = groupedDefinitions
        self.englishDefinition = englishDefinition
    }
}

// MARK: - SRS（间隔重复）算法
extension Vocabulary {
    /// 更新复习进度（基于SM-2算法）
    /// - Parameter quality: 复习质量评分 (0-5)
    mutating func updateReview(quality: Int) {
        let q = max(0, min(5, quality))

        // 更新难度因子
        easeFactor = max(1.3, easeFactor + 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02))

        // 计算新间隔
        if q < 3 {
            // 复习失败，重置间隔
            interval = 1
        } else {
            // 复习成功
            if reviewCount == 0 {
                interval = 1
            } else if reviewCount == 1 {
                interval = 6
            } else {
                interval = Int(Double(interval) * easeFactor)
            }
        }

        // 更新下次复习日期
        nextReviewDate = Calendar.current.date(byAdding: .day, value: interval, to: Date())
        reviewCount += 1
        lastReviewedAt = Date()

        // 更新掌握程度
        masteredLevel = q
    }

    /// 是否需要今天复习
    var needsReviewToday: Bool {
        guard let nextReview = nextReviewDate else {
            return true // 新词需要复习
        }
        return nextReview <= Date()
    }

    /// 获取下一次复习的相对时间描述
    var nextReviewDescription: String {
        guard let nextReview = nextReviewDate else {
            return L("mastery.notStarted")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: nextReview, relativeTo: Date())
    }

    /// 格式化的掌握程度描述
    var masteredLevelDescription: String {
        switch masteredLevel {
        case 0: return L("mastery.unlearned")
        case 1: return L("mastery.poor")
        case 2: return L("mastery.learning")
        case 3: return L("mastery.familiar")
        case 4: return L("mastery.proficient")
        case 5: return L("mastery.mastered")
        default: return L("mastery.unknown")
        }
    }
}