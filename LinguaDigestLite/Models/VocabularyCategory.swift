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
                name: L("category.all"),
                description: L("category.allDesc"),
                color: "#007AFF",
                icon: "tray.full",
                isDefault: true,
                order: 0
            ),
            VocabularyCategory(
                name: L("category.tech"),
                description: L("category.techDesc"),
                color: "#5856D6",
                icon: "cpu",
                isDefault: true,
                order: 1
            ),
            VocabularyCategory(
                name: L("category.politics"),
                description: L("category.politicsDesc"),
                color: "#FF9500",
                icon: "building.2",
                isDefault: true,
                order: 2
            ),
            VocabularyCategory(
                name: L("category.economy"),
                description: L("category.economyDesc"),
                color: "#34C759",
                icon: "chart.line.uptrend.xyaxis",
                isDefault: true,
                order: 3
            ),
            VocabularyCategory(
                name: L("category.culture"),
                description: L("category.cultureDesc"),
                color: "#FF2D55",
                icon: "theatermasks",
                isDefault: true,
                order: 4
            ),
            VocabularyCategory(
                name: L("category.daily"),
                description: L("category.dailyDesc"),
                color: "#64D2FF",
                icon: "house",
                isDefault: true,
                order: 5
            ),
            VocabularyCategory(
                name: L("category.writing"),
                description: L("category.writingDesc"),
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
            (L("color.blue"), "#007AFF"),
            (L("color.purple"), "#5856D6"),
            (L("color.orange"), "#FF9500"),
            (L("color.green"), "#34C759"),
            (L("color.red"), "#FF2D55"),
            (L("color.teal"), "#64D2FF"),
            (L("color.pink"), "#AF52DE"),
            (L("color.yellow"), "#FFCC00"),
            (L("color.brown"), "#A2845E"),
            (L("color.gray"), "#8E8E93")
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