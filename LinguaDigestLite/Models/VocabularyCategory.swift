//
//  VocabularyCategory.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation

/// 生词分类模型
struct VocabularyCategory: Identifiable, Codable {
    var id: UUID
    var name: String
    var description: String?
    var color: String // 十六进制颜色码
    var icon: String // SF Symbol图标名称
    var createdAt: Date
    var isDefault: Bool // 是否为默认分类
    var order: Int // 排序顺序

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        color: String = "#007AFF", // 默认蓝色
        icon: String = "folder",
        isDefault: Bool = false,
        order: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.color = color
        self.icon = icon
        self.createdAt = Date()
        self.isDefault = isDefault
        self.order = order
    }
}

// MARK: - 默认分类
extension VocabularyCategory {
    /// 默认分类列表
    static var defaultCategories: [VocabularyCategory] {
        [
            VocabularyCategory(
                name: "全部",
                description: "所有生词",
                color: "#007AFF",
                icon: "tray.full",
                isDefault: true,
                order: 0
            ),
            VocabularyCategory(
                name: "科技",
                description: "科技相关词汇",
                color: "#5856D6",
                icon: "cpu",
                isDefault: true,
                order: 1
            ),
            VocabularyCategory(
                name: "政治",
                description: "政治新闻词汇",
                color: "#FF9500",
                icon: "building.2",
                isDefault: true,
                order: 2
            ),
            VocabularyCategory(
                name: "经济",
                description: "经济财经词汇",
                color: "#34C759",
                icon: "chart.line.uptrend.xyaxis",
                isDefault: true,
                order: 3
            ),
            VocabularyCategory(
                name: "文化",
                description: "文化生活词汇",
                color: "#FF2D55",
                icon: "theatermasks",
                isDefault: true,
                order: 4
            ),
            VocabularyCategory(
                name: "日常",
                description: "日常常用词汇",
                color: "#64D2FF",
                icon: "house",
                isDefault: true,
                order: 5
            ),
            VocabularyCategory(
                name: "写作",
                description: "写作表达词汇",
                color: "#AF52DE",
                icon: "pencil",
                isDefault: true,
                order: 6
            )
        ]
    }
    
    /// 获取默认分类（全部）
    static var allCategory: VocabularyCategory {
        defaultCategories.first { $0.name == "全部" } ?? defaultCategories[0]
    }
}

// MARK: - 颜色辅助
extension VocabularyCategory {
    /// 可选颜色列表
    static var availableColors: [(name: String, hex: String)] {
        [
            ("蓝色", "#007AFF"),
            ("紫色", "#5856D6"),
            ("橙色", "#FF9500"),
            ("绿色", "#34C759"),
            ("红色", "#FF2D55"),
            ("青色", "#64D2FF"),
            ("粉色", "#AF52DE"),
            ("黄色", "#FFCC00"),
            ("棕色", "#A2845E"),
            ("灰色", "#8E8E93")
        ]
    }
    
    /// 可选图标列表
    static var availableIcons: [String] {
        [
            "folder",
            "tray.full",
            "book",
            "bookmark",
            "star",
            "heart",
            "tag",
            "flag",
            "cpu",
            "building.2",
            "chart.line.uptrend.xyaxis",
            "theatermasks",
            "house",
            "pencil",
            "lightbulb",
            "globe",
            "briefcase",
            "graduationcap",
            "sciences",
            "leaf"
        ]
    }
}