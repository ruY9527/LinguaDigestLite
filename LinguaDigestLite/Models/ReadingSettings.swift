//
//  ReadingSettings.swift
//  LinguaDigestLite
//
//  Created for LinguaDigestLite
//

import Foundation

/// 阅读设置
struct ReadingSettings: Codable {
    var fontSize: CGFloat
    var lineHeight: CGFloat
    var paragraphSpacing: CGFloat
    var marginSize: CGFloat
    var theme: ReadingTheme
    var fontName: String?
    var autoHighlightNewWords: Bool
    var vocabularyLevel: VocabularyLevel
    var showPhonetic: Bool
    var speechRate: Float // 朗读速度 0.3-0.8

    init() {
        self.fontSize = 17
        self.lineHeight = 1.5
        self.paragraphSpacing = 12
        self.marginSize = 16
        self.theme = .light
        self.autoHighlightNewWords = true
        self.vocabularyLevel = .intermediate
        self.showPhonetic = true
        self.speechRate = 0.5
    }
    
    static let standardFonts = [
        "System": nil,
        "Georgia": "Georgia",
        "Charter": "Charter",
        "Lora": "Lora-Regular",
        "Palatino": "Palatino",
        "Times New Roman": "TimesNewRomanPSMT"
    ]
}

/// 阅读主题
enum ReadingTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case sepia = "sepia"
    case green = "green"
    
    var displayName: String {
        switch self {
        case .light: return "日间模式"
        case .dark: return "夜间模式"
        case .sepia: return "护眼黄纸"
        case .green: return "护眼绿"
        }
    }
    
    var backgroundColor: String {
        switch self {
        case .light: return "#FFFFFF"
        case .dark: return "#1C1C1E"
        case .sepia: return "#F4ECD8"
        case .green: return "#E8F5E9"
        }
    }
    
    var textColor: String {
        switch self {
        case .light: return "#000000"
        case .dark: return "#FFFFFF"
        case .sepia: return "#5B4636"
        case .green: return "#2E7D32"
        }
    }
}

/// 词汇等级
enum VocabularyLevel: String, Codable, CaseIterable {
    case beginner = "beginner"
    case elementary = "elementary"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner: return "初学者 (Oxford 1000)"
        case .elementary: return "初级 (Oxford 2000)"
        case .intermediate: return "中级 (Oxford 3000)"
        case .advanced: return "高级 (Oxford 5000)"
        case .expert: return "专家级 (全词表)"
        }
    }
    
    /// 返回已知词汇表名称
    var knownWordsSetName: String {
        switch self {
        case .beginner: return "oxford_1000"
        case .elementary: return "oxford_2000"
        case .intermediate: return "oxford_3000"
        case .advanced: return "oxford_5000"
        case .expert: return "all_words"
        }
    }
}

/// 用户设置管理
class UserSettings: ObservableObject {
    static let shared = UserSettings()
    
    private let defaults = UserDefaults.standard
    private let readingSettingsKey = "readingSettings"
    
    @Published var readingSettings: ReadingSettings {
        didSet {
            saveReadingSettings()
        }
    }
    
    private init() {
        if let data = defaults.data(forKey: readingSettingsKey),
           let settings = try? JSONDecoder().decode(ReadingSettings.self, from: data) {
            self.readingSettings = settings
        } else {
            self.readingSettings = ReadingSettings()
        }
    }
    
    private func saveReadingSettings() {
        guard let data = try? JSONEncoder().encode(readingSettings) else { return }
        defaults.set(data, forKey: readingSettingsKey)
    }
    
    func resetToDefaults() {
        readingSettings = ReadingSettings()
    }
}