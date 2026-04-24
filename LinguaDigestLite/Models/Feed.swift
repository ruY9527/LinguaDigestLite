//
//  Feed.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation

/// RSS订阅源模型（简化版，不依赖GRDB）
struct Feed: Identifiable, Codable {
    var id: UUID
    var title: String
    var link: String
    var feedUrl: String
    var description: String? // RSS源自动描述
    var notes: String? // 用户自定义备注
    var imageUrl: String?
    var lastUpdated: Date?
    var isActive: Bool
    var isBuiltIn: Bool
    var createdAt: Date
    var updateInterval: Int // 更新间隔（分钟）

    init(
        id: UUID = UUID(),
        title: String,
        link: String,
        feedUrl: String,
        description: String? = nil,
        notes: String? = nil,
        imageUrl: String? = nil,
        isBuiltIn: Bool = false,
        updateInterval: Int = 60
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.feedUrl = feedUrl
        self.description = description
        self.notes = notes
        self.imageUrl = imageUrl
        self.isActive = true
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.updateInterval = updateInterval
    }
}

// MARK: - 内置RSS源
extension Feed {
    /// 内置的优质英语外刊RSS源
    static let builtInFeeds: [Feed] = [
        // 科技类
        Feed(
            title: "BBC News - Technology",
            link: "https://www.bbc.co.uk/news/technology",
            feedUrl: "https://feeds.bbci.co.uk/news/technology/rss.xml",
            description: "BBC Technology News",
            isBuiltIn: true
        ),
        Feed(
            title: "The Guardian - Technology",
            link: "https://www.theguardian.com/technology",
            feedUrl: "https://www.theguardian.com/technology/rss",
            description: "The Guardian Technology section",
            isBuiltIn: true
        ),
        Feed(
            title: "NPR - Technology",
            link: "https://www.npr.org/sections/technology/",
            feedUrl: "https://feeds.npr.org/1019/rss.xml",
            description: "NPR Technology News",
            isBuiltIn: true
        ),
        Feed(
            title: "MIT Technology Review",
            link: "https://www.technologyreview.com/",
            feedUrl: "https://www.technologyreview.com/feed/",
            description: "MIT Technology Review",
            isBuiltIn: true
        ),
        // 科学类
        Feed(
            title: "Science Daily",
            link: "https://www.sciencedaily.com/",
            feedUrl: "https://www.sciencedaily.com/rss/all.xml",
            description: "Science Daily - Latest Science News",
            isBuiltIn: true
        ),
        Feed(
            title: "Nature - Latest Research",
            link: "https://www.nature.com/",
            feedUrl: "https://www.nature.com/nature.rss",
            description: "Nature journal latest articles",
            isBuiltIn: true
        ),
        Feed(
            title: "Scientific American",
            link: "https://www.scientificamerican.com/",
            feedUrl: "https://www.scientificamerican.com/feed/",
            description: "Scientific American",
            isBuiltIn: true
        ),
        // 商业/经济类
        Feed(
            title: "Harvard Business Review",
            link: "https://hbr.org/",
            feedUrl: "https://hbr.org/feed",
            description: "Harvard Business Review",
            isBuiltIn: true
        ),
        Feed(
            title: "The Economist - Business",
            link: "https://www.economist.com/business",
            feedUrl: "https://www.economist.com/business/rss.xml",
            description: "The Economist Business",
            isBuiltIn: true
        ),
        // 世界新闻
        Feed(
            title: "BBC World News",
            link: "https://www.bbc.co.uk/news/world",
            feedUrl: "https://feeds.bbci.co.uk/news/world/rss.xml",
            description: "BBC World News",
            isBuiltIn: true
        ),
        Feed(
            title: "NPR - World",
            link: "https://www.npr.org/sections/world/",
            feedUrl: "https://feeds.npr.org/1004/rss.xml",
            description: "NPR World News",
            isBuiltIn: true
        ),
        Feed(
            title: "The Guardian - World",
            link: "https://www.theguardian.com/world",
            feedUrl: "https://www.theguardian.com/world/rss",
            description: "The Guardian World News",
            isBuiltIn: true
        ),
        // 文化/生活
        Feed(
            title: "NPR - Culture",
            link: "https://www.npr.org/sections/culture/",
            feedUrl: "https://feeds.npr.org/1008/rss.xml",
            description: "NPR Culture",
            isBuiltIn: true
        ),
        Feed(
            title: "The Guardian - Books",
            link: "https://www.theguardian.com/books",
            feedUrl: "https://www.theguardian.com/books/rss",
            description: "The Guardian Books",
            isBuiltIn: true
        ),
        // 健康
        Feed(
            title: "NPR - Health",
            link: "https://www.npr.org/sections/health/",
            feedUrl: "https://feeds.npr.org/1128/rss.xml",
            description: "NPR Health News",
            isBuiltIn: true
        ),
        Feed(
            title: "BBC Health",
            link: "https://www.bbc.co.uk/news/health",
            feedUrl: "https://feeds.bbci.co.uk/news/health/rss.xml",
            description: "BBC Health News",
            isBuiltIn: true
        ),
        // 环境
        Feed(
            title: "The Guardian - Environment",
            link: "https://www.theguardian.com/environment",
            feedUrl: "https://www.theguardian.com/environment/rss",
            description: "The Guardian Environment",
            isBuiltIn: true
        ),
        // 科技博客
        Feed(
            title: "Ars Technica",
            link: "https://arstechnica.com/",
            feedUrl: "https://feeds.arstechnica.com/arstechnica/index",
            description: "Ars Technica - Technology News",
            isBuiltIn: true
        ),
        Feed(
            title: "Wired",
            link: "https://www.wired.com/",
            feedUrl: "https://www.wired.com/feed/rss",
            description: "Wired Magazine",
            isBuiltIn: true
        ),
        Feed(
            title: "TechCrunch",
            link: "https://techcrunch.com/",
            feedUrl: "https://techcrunch.com/feed/",
            description: "TechCrunch - Startup and Tech News",
            isBuiltIn: true
        ),
        // 新闻综合
        Feed(
            title: "BBC Top Stories",
            link: "https://www.bbc.co.uk/news",
            feedUrl: "https://feeds.bbci.co.uk/news/rss.xml",
            description: "BBC News Top Stories",
            isBuiltIn: true
        ),
        Feed(
            title: "The Guardian - US News",
            link: "https://www.theguardian.com/us-news",
            feedUrl: "https://www.theguardian.com/us-news/rss",
            description: "The Guardian US News",
            isBuiltIn: true
        ),
        Feed(
            title: "NPR - Politics",
            link: "https://www.npr.org/sections/politics/",
            feedUrl: "https://feeds.npr.org/1014/rss.xml",
            description: "NPR Politics",
            isBuiltIn: true
        ),
        // 体育
        Feed(
            title: "BBC Sport",
            link: "https://www.bbc.co.uk/sport",
            feedUrl: "https://feeds.bbci.co.uk/sport/rss.xml",
            description: "BBC Sport",
            isBuiltIn: true
        ),
        // 艺术
        Feed(
            title: "The Guardian - Art and Design",
            link: "https://www.theguardian.com/artanddesign",
            feedUrl: "https://www.theguardian.com/artanddesign/rss",
            description: "The Guardian Art and Design",
            isBuiltIn: true
        ),
        // 旅行
        Feed(
            title: "BBC Travel",
            link: "https://www.bbc.com/travel",
            feedUrl: "https://feeds.bbci.co.uk/travel/rss.xml",
            description: "BBC Travel",
            isBuiltIn: true
        ),
        // 未来/创新
        Feed(
            title: "BBC Future",
            link: "https://www.bbc.com/future",
            feedUrl: "https://feeds.bbci.co.uk/future/rss.xml",
            description: "BBC Future - Science and Ideas",
            isBuiltIn: true
        ),
        // 心理学
        Feed(
            title: "Psychology Today",
            link: "https://www.psychologytoday.com/",
            feedUrl: "https://www.psychologytoday.com/rss",
            description: "Psychology Today",
            isBuiltIn: true
        ),
        // 艺术/文化
        Feed(
            title: "Smithsonian Magazine",
            link: "https://www.smithsonianmag.com/",
            feedUrl: "https://www.smithsonianmag.com/rss/",
            description: "Smithsonian Magazine",
            isBuiltIn: true
        )
    ]
}