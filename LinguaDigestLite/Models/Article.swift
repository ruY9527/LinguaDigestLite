//
//  Article.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation

/// 文章模型（简化版，不依赖GRDB）
struct Article: Identifiable, Codable {
    var id: UUID
    var feedId: UUID?
    var title: String
    var link: String
    var author: String?
    var summary: String?
    var content: String?
    var htmlContent: String?
    var imageUrl: String?
    var publishedAt: Date?
    var fetchedAt: Date
    var isRead: Bool
    var isFavorite: Bool
    var readingProgress: Double // 0.0 - 1.0
    
    init(
        id: UUID = UUID(),
        feedId: UUID? = nil,
        title: String,
        link: String,
        author: String? = nil,
        summary: String? = nil,
        content: String? = nil,
        htmlContent: String? = nil,
        imageUrl: String? = nil,
        publishedAt: Date? = nil
    ) {
        self.id = id
        self.feedId = feedId
        self.title = title
        self.link = link
        self.author = author
        self.summary = summary
        self.content = content
        self.htmlContent = htmlContent
        self.imageUrl = imageUrl
        self.publishedAt = publishedAt
        self.fetchedAt = Date()
        self.isRead = false
        self.isFavorite = false
        self.readingProgress = 0.0
    }
}

// MARK: - 文章扩展
extension Article {
    /// 获取预览文本
    var previewText: String {
        if let summary = summary, !summary.isEmpty {
            return String(summary.prefix(200))
        }
        if let content = content, !content.isEmpty {
            return String(content.prefix(200))
        }
        return "无预览内容"
    }
    
    /// 格式化的发布日期
    var formattedDate: String {
        guard let date = publishedAt else {
            return "未知日期"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}